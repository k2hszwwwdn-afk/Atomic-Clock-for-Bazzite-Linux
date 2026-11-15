import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.plasma.plasmoid

KCM.SimpleKCM {
    id: configPage

    property alias cfg_timeZone: timeZoneField.text
    property string cfg_timeZoneDefault: ""
    property alias cfg_hourFormat: hourFormat.configValue
    property int cfg_hourFormatDefault: 24
    property alias cfg_readoutColor: readoutColorField.text
    property string cfg_readoutColorDefault: "#57ef7e"
    property alias cfg_transparentBackground: transparentBackground.checked
    property bool cfg_transparentBackgroundDefault: true

    function saveConfig() {
        Plasmoid.configuration.timeZone = cfg_timeZone
        Plasmoid.configuration.hourFormat = cfg_hourFormat
        Plasmoid.configuration.readoutColor = cfg_readoutColor
        Plasmoid.configuration.transparentBackground = cfg_transparentBackground
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8

        QQC2.Label {
            text: "Time zone (IANA name)"
        }

        QQC2.TextField {
            id: timeZoneField
            placeholderText: "Blank uses the system time zone"
            Layout.fillWidth: true
        }

        QQC2.Label {
            text: "Examples: America/Chicago, Europe/London, Asia/Tokyo, UTC"
            color: palette.mid
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        QQC2.Label {
            text: "Time format"
            Layout.topMargin: 8
        }

        QQC2.ComboBox {
            id: hourFormat
            model: ["24-hour", "12-hour"]
            property int configValue: 24
            currentIndex: configValue === 12 ? 1 : 0
            onActivated: configValue = currentIndex === 1 ? 12 : 24
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
