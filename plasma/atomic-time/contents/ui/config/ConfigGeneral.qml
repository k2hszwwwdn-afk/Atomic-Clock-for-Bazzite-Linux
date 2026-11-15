import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: configPage

    property alias cfg_readoutColor: readoutColorField.text
    property string cfg_readoutColorDefault: "#57ef7e"
    property alias cfg_transparentBackground: transparentBackground.checked
    property bool cfg_transparentBackgroundDefault: true

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8

        QQC2.Label {
            text: "The time zone and display format follow the Atomic Time app."
            color: palette.text
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        QQC2.Label {
            text: "Readout color"
            Layout.topMargin: 8
        }

        RowLayout {
            Layout.fillWidth: true

            Rectangle {
                implicitWidth: 32
                implicitHeight: 32
                radius: 5
                color: readoutColorField.text
                border.color: palette.mid
            }

            QQC2.TextField {
                id: readoutColorField
                readOnly: true
                Layout.fillWidth: true
            }

            QQC2.Button {
                text: "Choose color..."
                onClicked: colorDialog.open()
            }
        }

        QQC2.Switch {
            id: transparentBackground
            text: "Transparent background"
            Layout.topMargin: 8
        }
    }

    ColorDialog {
        id: colorDialog
        title: "Choose readout color"
        selectedColor: configPage.cfg_readoutColor
        onAccepted: readoutColorField.text = Qt.rgba(
            selectedColor.r, selectedColor.g, selectedColor.b, 1
        ).toString()
    }
}
