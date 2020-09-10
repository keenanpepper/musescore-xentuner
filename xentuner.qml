import QtQuick 2.9
import MuseScore 3.0
import QtQuick.Controls 1.5
import QtQuick.Dialogs 1.2
import FileIO 3.0

MuseScore {
  menuPath: "Plugins.Xenharmonic Tuner"
  description: "Allows microtonal retuning of both natural notes and accidentals."
  version: "1.0"
  pluginType: "dialog"
  width: 377
  height: 233
  Button {
    id: "loadButton"
    text: "Select tuning file"
    anchors.centerIn: parent
    onClicked: {
      fileDialog.open();
    }
  }
  Button {
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    text: "Cancel"
    onClicked: {
      Qt.quit();
    }
  }
  Button {
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    text: "Apply selected tuning to score"
    onClicked: {
      var tuningData = parseTuningFileContent(tuningFile.read());
      console.log("tuningData: " + JSON.stringify(tuningData));
      applyToNotesInSelection(function(note) {
        tuneNote(note, tuningData);
      });
      Qt.quit();
    }
  }
  Text {
    id: "fileLabel"
    width: parent.width
    wrapMode: Text.WrapAnywhere
  }
  function getNatural(pitch, tpc) {
    // since which natural (A-G) isn't directly available, need to compute it
    // middle C is 0, D above is 1, B below is -1, etc.
    var answerMod7 = (4 * tpc + 7) % 7;
    var firstOctavePitch = 60 + answerMod7 * 12 / 7;
    var numOctaves = Math.round((pitch - firstOctavePitch) / 12);
    return answerMod7 + numOctaves * 7;
  }
  function parseTuningFileContent(fileContent) {
    var obj = JSON.parse(fileContent);
    if (!obj.naturals) {
      throw "No naturals found";
    }
    if (!Array.isArray(obj.naturals)) {
      throw "\"naturals\" property is not an array";
    }
    if (!obj.accidentals) {
      throw "No accidentals found";
    }
    return obj;
  }
  function computeTuning(natural, accidentalType, tuningData) {
    // return value in cents relative to middle C

    var numNaturals = tuningData["naturals"].length;
    var naturalIndex = natural % numNaturals;
    if (naturalIndex < 0) naturalIndex += numNaturals;
    var numPeriods = (natural - naturalIndex) / numNaturals;
    var period = tuningData["naturals"][numNaturals - 1];
    var base;
    if (naturalIndex == 0) {
      base = numPeriods * period;
    } else {
      base = numPeriods * period + tuningData["naturals"][naturalIndex - 1];
    }

    var accidental = getAccidentalName(accidentalType);
    if (!tuningData["accidentals"].hasOwnProperty(accidental)) {
      return base;
    }
    var modifier = tuningData["accidentals"][accidental]

    return base + modifier;
  }
  function getAccidentalName(accidentalType) {
    // hardcoded for now, but should use AccidentalType enum
    var namesList = ["NONE","FLAT","NATURAL","SHARP","SHARP2","FLAT2","NATURAL_FLAT","NATURAL_SHARP","SHARP_SHARP","FLAT_ARROW_UP","FLAT_ARROW_DOWN","NATURAL_ARROW_UP","NATURAL_ARROW_DOWN","SHARP_ARROW_UP","SHARP_ARROW_DOWN","SHARP2_ARROW_UP","SHARP2_ARROW_DOWN","FLAT2_ARROW_UP","FLAT2_ARROW_DOWN","MIRRORED_FLAT","MIRRORED_FLAT2","SHARP_SLASH","SHARP_SLASH4","FLAT_SLASH2","FLAT_SLASH","SHARP_SLASH3","SHARP_SLASH2","DOUBLE_FLAT_ONE_ARROW_DOWN","FLAT_ONE_ARROW_DOWN","NATURAL_ONE_ARROW_DOWN","SHARP_ONE_ARROW_DOWN","DOUBLE_SHARP_ONE_ARROW_DOWN","DOUBLE_FLAT_ONE_ARROW_UP","FLAT_ONE_ARROW_UP","NATURAL_ONE_ARROW_UP","SHARP_ONE_ARROW_UP","DOUBLE_SHARP_ONE_ARROW_UP","DOUBLE_FLAT_TWO_ARROWS_DOWN","FLAT_TWO_ARROWS_DOWN","NATURAL_TWO_ARROWS_DOWN","SHARP_TWO_ARROWS_DOWN","DOUBLE_SHARP_TWO_ARROWS_DOWN","DOUBLE_FLAT_TWO_ARROWS_UP","FLAT_TWO_ARROWS_UP","NATURAL_TWO_ARROWS_UP","SHARP_TWO_ARROWS_UP","DOUBLE_SHARP_TWO_ARROWS_UP","DOUBLE_FLAT_THREE_ARROWS_DOWN","FLAT_THREE_ARROWS_DOWN","NATURAL_THREE_ARROWS_DOWN","SHARP_THREE_ARROWS_DOWN","DOUBLE_SHARP_THREE_ARROWS_DOWN","DOUBLE_FLAT_THREE_ARROWS_UP","FLAT_THREE_ARROWS_UP","NATURAL_THREE_ARROWS_UP","SHARP_THREE_ARROWS_UP","DOUBLE_SHARP_THREE_ARROWS_UP","LOWER_ONE_SEPTIMAL_COMMA","RAISE_ONE_SEPTIMAL_COMMA","LOWER_TWO_SEPTIMAL_COMMAS","RAISE_TWO_SEPTIMAL_COMMAS","LOWER_ONE_UNDECIMAL_QUARTERTONE","RAISE_ONE_UNDECIMAL_QUARTERTONE","LOWER_ONE_TRIDECIMAL_QUARTERTONE","RAISE_ONE_TRIDECIMAL_QUARTERTONE","DOUBLE_FLAT_EQUAL_TEMPERED","FLAT_EQUAL_TEMPERED","NATURAL_EQUAL_TEMPERED","SHARP_EQUAL_TEMPERED","DOUBLE_SHARP_EQUAL_TEMPERED","QUARTER_FLAT_EQUAL_TEMPERED","QUARTER_SHARP_EQUAL_TEMPERED","SORI","KORON"];
    return namesList[0+accidentalType];
  }
  function tuneNote(note, tuningData) {
    console.log("pitch: " + note.pitch, ", tpc: " + note.tpc, " accidentalType: " + note.accidentalType, " natural: " + getNatural(note.pitch, note.tpc));
    var absolute = computeTuning(getNatural(note.pitch, note.tpc), note.accidentalType, tuningData);
    var relative = absolute - (note.pitch - 60) * 100;
    note.tuning = relative;
  }
  function loadSettings() {
    var fileContent = settingsFile.read();
    var obj = JSON.parse(fileContent);
    if (obj.hasOwnProperty("tuningFile")) {
      tuningFile.source = obj.tuningFile;
      fileLabel.text = "Tuning file: " + obj.tuningFile;
    }
  }
  function writeSettings(settings) {
    settingsFile.write(JSON.stringify(settings));
  }
  FileDialog {
    id: fileDialog
    title: "Please choose a file"
    folder: shortcuts.home
    onAccepted: {
        tuningFile.source = fileDialog.fileUrl;
        fileLabel.text = "Tuning file: " + fileDialog.fileUrl;
        writeSettings({tuningFile: "" + fileDialog.fileUrl});
    }
    onRejected: {
    }
  }
  FileIO {
    id: "tuningFile"
    onError: {
      console.log(msg);
    }
  }
  FileIO {
    id: "settingsFile"
    source: homePath() + "/.musescore-xentuner-settings.json"
    onError: {
      console.log(msg);
    }
  }
  onRun: {
  }
  Component.onCompleted: {
    if (settingsFile.exists()) {
      loadSettings();
    } else {
      fileLabel.text = "No file selected";
    }
  }

        // from colornotes.qml, GPL2 licensed
        function applyToNotesInSelection(func) {
            var cursor = curScore.newCursor();
            cursor.rewind(1);
            var startStaff;
            var endStaff;
            var endTick;
            var fullScore = false;
            if (!cursor.segment) { // no selection
                  fullScore = true;
                  startStaff = 0; // start with 1st staff
                  endStaff = curScore.nstaves - 1; // and end with last
            } else {
                  startStaff = cursor.staffIdx;
                  cursor.rewind(2);
                  if (cursor.tick === 0) {
                        // this happens when the selection includes
                        // the last measure of the score.
                        // rewind(2) goes behind the last segment (where
                        // there's none) and sets tick=0
                        endTick = curScore.lastSegment.tick + 1;
                  } else {
                        endTick = cursor.tick;
                  }
                  endStaff = cursor.staffIdx;
            }
            console.log(startStaff + " - " + endStaff + " - " + endTick)
            for (var staff = startStaff; staff <= endStaff; staff++) {
                  for (var voice = 0; voice < 4; voice++) {
                        cursor.rewind(1); // sets voice to 0
                        cursor.voice = voice; //voice has to be set after goTo
                        cursor.staffIdx = staff;

                        if (fullScore)
                              cursor.rewind(0) // if no selection, beginning of score

                        while (cursor.segment && (fullScore || cursor.tick < endTick)) {
                              if (cursor.element && cursor.element.type === Element.CHORD) {
                                    var graceChords = cursor.element.graceNotes;
                                    for (var i = 0; i < graceChords.length; i++) {
                                          // iterate through all grace chords
                                          var graceNotes = graceChords[i].notes;
                                          for (var j = 0; j < graceNotes.length; j++)
                                                func(graceNotes[j]);
                                    }
                                    var notes = cursor.element.notes;
                                    for (var k = 0; k < notes.length; k++) {
                                          var note = notes[k];
                                          func(note);
                                    }
                              }
                              cursor.next();
                        }
                  }
            }
      }

}
