// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs.core

// Lock screen state: locking, the password check (PAM), lock on idle, lock
// before sleep, and logind's lock/unlock requests. The lock surfaces live in
// lock/LockScreen.qml and only exist while locked.
//
// Safety (see README "If the lock screen breaks"):
// - A wrong password never unlocks. Only PAM's "Success" (or logind's
//   Unlock, i.e. `loginctl unlock-session` from a TTY) does.
// - A flag file in $XDG_RUNTIME_DIR marks "locked": if the shell dies while
//   locked, Hyprland keeps the session locked, and the restarted shell
//   (SUPER + SHIFT + R also works on the lock screen) locks again at once
//   (misc.allow_session_lock_restore, set by hypr/init.lua).
// - If PAM itself fails (missing module, broken config: not a wrong
//   password), the lock says so and, FOR NOW (testing phase), offers an
//   Unlock button. TODO(before v0.3.0): remove `broken` unlocking.
Singleton {
    id: root

    // ---- State ---------------------------------------------------------------------
    property bool locked: false        // asked for; WlSessionLock.locked follows it
    property bool secure: false        // the compositor confirmed: every screen covered
    property string buffer: ""         // what is typed (never logged, cleared on unlock)
    // "idle" | "checking" | "failed" | "success" | "error" | "prompt"
    property string status: "idle"
    property string message: ""        // from PAM (e.g. faillock), or ours
    property string prompt: ""         // a second PAM question (e.g. a one-time code)
    property int failures: 0
    readonly property bool broken: status === "error"
    property real lockedAt: 0

    signal typed(int delta)            // +1 a character, -1 deleted one, 0 cleared
    signal rejected()                  // wrong password: shake

    // The system's own login rules (/etc/pam.d/login), like swaylock and
    // hyprlock. (A file of our own with "auth include login" does not work:
    // PAM resolves the include in the same custom directory.)
    // The environment overrides exist for testing only (a nested Hyprland
    // with a test PAM file); they add no way in that the session lock
    // restore doesn't already give any program running as the user.
    readonly property string pamDir: Quickshell.env("ALTAIR_LOCK_PAM_DIR") || "/etc/pam.d"
    readonly property string pamConfig: Quickshell.env("ALTAIR_LOCK_PAM_CONFIG") || "login"

    readonly property string runtimeDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/altair"
    // Per Hyprland instance: a Hyprland started anew is not locked.
    readonly property string flagFile: runtimeDir + "/locked-" + (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "session")
    readonly property string sessionId: Quickshell.env("XDG_SESSION_ID") || ""
    readonly property string sessionPath: sessionId ? "/org/freedesktop/login1/session/" + busEscape(sessionId) : ""

    // ---- Locking -------------------------------------------------------------------
    function lock(): void {
        if (locked)
            return;
        console.info("altair: locking");
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && : > "$2"', "sh", runtimeDir, flagFile]);
        buffer = "";
        status = "idle";
        message = "";
        prompt = "";
        failures = 0;
        lockedAt = Date.now();
        locked = true;
    }

    function unlock(): void {
        if (!locked)
            return;
        console.info("altair: unlocked");
        if (pam.active)
            pam.abort();
        buffer = "";
        pending = null;
        locked = false;
        Quickshell.execDetached(["rm", "-f", flagFile]);
        setLockedHint(false);
    }

    // TEMPORARY (testing phase): only while PAM itself is broken.
    function forceUnlock(): void {
        if (broken) {
            console.warn("altair: unlocking without a password check (PAM is broken)");
            unlock();
        }
    }

    onSecureChanged: if (secure) setLockedHint(true)

    // logind's LockedHint: other programs (and `loginctl`) see the session as locked.
    function setLockedHint(on: bool): void {
        if (sessionPath)
            Quickshell.execDetached(["busctl", "call", "org.freedesktop.login1", sessionPath,
                "org.freedesktop.login1.Session", "SetLockedHint", "b", on ? "true" : "false"]);
    }

    // systemd's object path escaping: "2" -> "_32".
    function busEscape(s: string): string {
        let out = "";
        for (let i = 0; i < s.length; i++) {
            const c = s[i];
            out += /[A-Za-z0-9]/.test(c) && !(i === 0 && /[0-9]/.test(c)) ? c : "_" + c.charCodeAt(0).toString(16).padStart(2, "0");
        }
        return out;
    }

    // Locked before the shell (re)started: lock again right away.
    Process {
        running: true
        command: ["test", "-e", root.flagFile]
        onExited: code => {
            if (code === 0) {
                console.warn("altair: the session was locked when the shell stopped; locking again");
                root.lock();
            }
        }
    }

    // ---- Typing --------------------------------------------------------------------
    function type(text: string): void {
        if (status === "checking" || status === "success" || !text)
            return;
        if (status === "failed") {
            status = "idle";
            message = "";
        }
        buffer += text;
        typed(1);
    }
    function backspace(): void {
        if (status === "checking" || status === "success" || !buffer)
            return;
        buffer = buffer.slice(0, -1);
        typed(-1);
    }
    function clear(): void {
        if (status === "checking" || status === "success" || !buffer)
            return;
        buffer = "";
        typed(0);
    }

    // ---- Password check --------------------------------------------------------------
    property var pending: null   // the answer to give when PAM asks

    function submit(): void {
        if (status === "checking" || status === "success")
            return;
        if (pam.active && pam.responseRequired) {
            // Answering a second question (prompt).
            status = "checking";
            const answer = buffer;
            buffer = "";
            pam.respond(answer);
            return;
        }
        if (!buffer)
            return;
        pending = buffer;
        status = "checking";
        message = "";
        if (!pam.start()) {
            pending = null;
            fail("error", "The password check couldn't start (PAM). Check the log: journalctl --user -t qs");
        }
    }

    function fail(kind: string, text: string): void {
        status = kind;
        message = text;
        buffer = "";
        if (kind === "failed")
            rejected();
    }

    PamContext {
        id: pam
        configDirectory: root.pamDir
        config: root.pamConfig

        onPamMessage: {
            if (responseRequired) {
                if (root.pending !== null) {
                    respond(root.pending);
                    root.pending = null;
                } else {
                    // A further question: let the user answer it.
                    root.prompt = message;
                    root.buffer = "";
                    root.status = "prompt";
                }
            } else if (message) {
                // Information, e.g. faillock's "The account is locked …".
                root.message = message;
            }
        }
        onCompleted: result => {
            root.pending = null;
            root.prompt = "";
            if (result === PamResult.Success) {
                root.status = "success";
                root.buffer = "";
                root.message = "";
                unlockDelay.restart();
            } else if (result === PamResult.Failed || result === PamResult.MaxTries) {
                root.failures++;
                root.fail("failed", root.message || (root.failures >= 3 ? "Wrong password. Too many tries may lock the account for a while." : "Wrong password"));
            } else {
                root.fail("error", "The password check isn't working (PAM error). " + (root.message || "See journalctl -t qs."));
            }
        }
        onError: error => console.warn("altair: PAM error: " + PamError.toString(error))
    }

    // Lets the "unlocked" animation play before the surfaces go.
    Timer {
        id: unlockDelay
        interval: Config.ready && Config.effects.animations && !Config.performance.lowPower ? 420 : 0
        onTriggered: root.unlock()
    }

    // ---- Lock on idle, screen off ------------------------------------------------------
    readonly property int idleMinutes: Config.ready ? Math.max(0, Config.lock.idleMinutes) : 0
    readonly property int screenOffSeconds: Config.ready ? Math.max(0, Config.lock.screenOffSeconds) : 0

    // Quick settings > Keep awake: no lock on idle until switched off (or
    // the shell restarts). Locking by hand still works.
    property bool keepAwake: false

    // Idle inhibitors (a playing video, a game) keep the screen unlocked.
    IdleMonitor {
        enabled: root.idleMinutes > 0 && !root.locked && !root.keepAwake
        timeout: root.idleMinutes * 60
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) root.lock()
    }
    IdleMonitor {
        id: offMonitor
        enabled: root.secure && root.screenOffSeconds > 0
        timeout: root.screenOffSeconds
        respectInhibitors: true
        onIsIdleChanged: root.screenOn(!isIdle)
    }
    property bool screenIsOff: false
    function screenOn(on: bool): void {
        if (on === !screenIsOff)
            return;
        screenIsOff = !on;
        Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.dpms({ action = "${on ? "on" : "off"}" })`]);
    }
    onLockedChanged: if (!locked) screenOn(true)

    // ---- logind: Lock / Unlock requests, before sleep --------------------------------------
    // One `gdbus monitor` (event-driven, ~0 CPU). `loginctl lock-session`
    // locks; `loginctl unlock-session` (e.g. from a TTY) unlocks.
    Process {
        id: logind
        running: true
        // gdbus would outlive a killed shell (it only notices on its next
        // write), so `cat` watches our stdin: EOF = the shell is gone.
        stdinEnabled: true
        command: ["sh", "-c", 'gdbus monitor --system --dest org.freedesktop.login1 & p=$!; cat > /dev/null; kill $p']
        stdout: SplitParser {
            onRead: line => {
                if (root.sessionPath && line.startsWith(root.sessionPath + ":")) {
                    if (line.includes(".Session.Lock ("))
                        root.lock();
                    else if (line.includes(".Session.Unlock ("))
                        root.unlock();
                } else if (line.includes(".Manager.PrepareForSleep (true")) {
                    if (Config.lock.beforeSleep)
                        root.lock();
                } else if (line.includes(".Manager.PrepareForSleep (false")) {
                    root.screenOn(true);
                }
            }
        }
        onExited: logindRetry.start()
    }
    Timer {
        id: logindRetry
        interval: 5000
        onTriggered: logind.running = true
    }

    // A delay inhibitor: suspend waits (max a few seconds) until the screen is
    // locked. Held while unlocked; released once the lock is secure. `cat`
    // exits when the shell closes its stdin (also if the shell dies).
    Process {
        running: Config.ready && Config.lock.beforeSleep && !root.secure
        stdinEnabled: true
        command: ["systemd-inhibit", "--what=sleep", "--mode=delay", "--who=Altair",
            "--why=Locks the screen before sleep", "cat"]
    }
}
