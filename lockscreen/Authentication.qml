import QtQuick
import Quickshell
import Quickshell.Services.Pam

QtObject {
    id: auth
    property string userName: Quickshell.env("USER") || ""
    property string pamService: "hyprlock"
    property string pamDirectory: "/etc/pam.d"
    property string pendingResponse: ""
    property string message: ""
    readonly property bool busy: pam.active && !pam.responseRequired
    readonly property bool responseVisible: pam.responseVisible
    signal authenticated()

    function submit(response) {
        if (!response || busy) return;
        message = "";
        if (pam.active && pam.responseRequired) {
            pam.respond(response);
        } else {
            pendingResponse = response;
            if (!pam.start()) { pendingResponse = ""; message = "Authentication unavailable. Try again."; }
        }
    }

    property PamContext conversation: PamContext {
        id: pam
        user: auth.userName
        config: auth.pamService
        configDirectory: auth.pamDirectory
        onPamMessage: {
            if (responseRequired && auth.pendingResponse !== "") {
                const response = auth.pendingResponse;
                auth.pendingResponse = "";
                respond(response);
            } else if (message !== "") {
                auth.message = message;
            }
        }
        onCompleted: result => {
            auth.pendingResponse = "";
            if (result === PamResult.Success) {
                auth.message = "";
                auth.authenticated();
            } else {
                auth.message = "Couldn't unlock. Try again.";
            }
        }
        onError: error => {
            auth.pendingResponse = "";
            auth.message = "Authentication unavailable. Try again.";
        }
    }
}
