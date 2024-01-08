import QtQuick 2.9
import MuseScore 3.0
import QtQuick.Controls 1.5
import QtQuick.Dialogs 1.2
import FileIO 3.0

MuseScore {
  menuPath: "Plugins.Xenharmonic Tuner"
  description: "Allows microtonal retuning of both natural notes and accidentals."
  version: "2.0"
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
      qtQuit();
    }
  }
  Button {
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    text: "Apply selected tuning to score"
    onClicked: {
      try {
        var tuningData = parseTuningFileContent(tuningFile.read());
        debugLog("tuningData: " + JSON.stringify(tuningData));
      } catch (e) {
        fileLabel.text = "JSON parse error. Make sure your file has correct JSON syntax.";
        fileLabel.color = "red";
        return;
      }
      try {
        processSelection(tuningData);
        qtQuit();
      } catch (e) {
        fileLabel.text = "Some unknown error happened. Sorry!";
      }
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
  function getAccidentalName(accidentalType) {
    for (const accidentalName in Accidental) {
      if (Accidental[accidentalName] == accidentalType)
        return accidentalName;
    }
  }
  function getCentsOffset(accidentalType) {
    // Only for MuseScore 4.2 and later
    // see /src/engraving/dom/accidental.cpp
    const centsOffsets = [
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
-50,
-150,
50,
-50,
150,
50,
250,
150,
-150,
-250,
-50,
50,
-50,
-150,
50,
150,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
-6.8,
6.8,
-3.4,
3.4,
-16.5,
16.5,
-1.7,
1.7,
-10.9,
10.9,
33,
-67,
-167,
167,
-183,
183,
-17,
17,
-33,
33,
-50,
50,
-67,
67,
-83,
83,
0,
0,
-116,
116,
-133,
133,
-150,
150,
-5.8,
5.8,
-21.5,
21.5,
-27.3,
27.3,
-43,
43,
-48.8,
48.8,
-53.3,
53.3,
-60.4,
60.4,
-64.9,
64.9,
-70.7,
70.7,
-86.4,
86.4,
-92.2,
92.2,
-107.9,
107.9,
-113.7,
113.7,
-22.2,
22.2,
-44.4,
44.4,
-66.7,
66.7,
-88.9,
111.1
    ]
    debugLog("centsOffset: " + centsOffsets[0 + accidentalType]);
    return centsOffsets[0 + accidentalType];
  }
  function computeTuning(natural, accidentalType, tuningData) {
    // return value in cents relative to middle C

    var numNaturals = tuningData["naturals"].length;
    var naturalIndex = natural % numNaturals;
    if (naturalIndex < 0) naturalIndex += numNaturals;
    var numPeriods = (natural - naturalIndex) / numNaturals;
    var period = tuningData["naturals"][numNaturals - 1];
    var middleCPitch = tuningData["middleCPitch"]
    if (!middleCPitch) {
      middleCPitch = 0;
    }
    var base;
    if (naturalIndex == 0) {
      base = middleCPitch + numPeriods * period;
    } else {
      base = middleCPitch + numPeriods * period + tuningData["naturals"][naturalIndex - 1];
    }

    var accidental = getAccidentalName(accidentalType);
    if (!tuningData["accidentals"].hasOwnProperty(accidental)) {
      return base;
    }
    var modifier = tuningData["accidentals"][accidental]

    return base + modifier;
  }
  function processNote(note, accidentalMap, tuningData) {
    var natural = getNatural(note.pitch, note.tpc);

    // 1. if note carries an accidental, we're done
    var effectiveAccidental = note.accidentalType;

    // 2. if the pitch occurred previously in the same measure with
    // an accidental, or it was tied to a note with an accidental, use that
    if (effectiveAccidental == Accidental.NONE) {
      if (accidentalMap.hasOwnProperty(natural)) {
        effectiveAccidental = accidentalMap[natural];
      } else {
        var tiedNote = note;
        while (effectiveAccidental == Accidental.NONE) {
          if (tiedNote.tieBack) {
            tiedNote = tiedNote.tieBack.startNote;
            effectiveAccidental = tiedNote.accidentalType;
          } else {
            break;
          }
        }
      }
    }

    // 3. next rely on the standard key signature - custom key signatures
    // can't work yet since they are not exposed in the plugin API
    if (effectiveAccidental == Accidental.NONE) {
      if (note.tpc < 6) {
        effectiveAccidental = Accidental.FLAT2;
      } else if (note.tpc < 13) {
        effectiveAccidental = Accidental.FLAT;
      } else if (note.tpc < 20) {
        effectiveAccidental = Accidental.NONE;
      } else if (note.tpc < 27) {
        effectiveAccidental = Accidental.SHARP;
      } else {
        effectiveAccidental = Accidental.SHARP2;
      }
    }

    debugLog("pitch: " + note.pitch + " tpc: " + note.tpc + " accidentalType: " + note.accidentalType + " effectiveAccidental: " + effectiveAccidental + " natural: " + natural);
    const absolute = computeTuning(natural, effectiveAccidental, tuningData);
    var base = (note.pitch - 60) * 100;
    if ((mscoreMajorVersion == 4 && mscoreMinorVersion >= 2) || mscoreMajorVersion > 4) {
      base += getCentsOffset(effectiveAccidental);
    }
    const relative = absolute - base;
    debugLog("absolute: " + absolute + " relative: " + relative);
    note.tuning = relative;
    
    // record the accidental of this natural for later unmarked pitches in this measure
    accidentalMap[natural] = effectiveAccidental;
  }
  function loadSettings() {
    var fileContent = settingsFile.read();
    var obj = JSON.parse(fileContent);
    if (obj.hasOwnProperty("tuningFile")) {
      tuningFile.source = obj.tuningFile;
      fileLabel.text = "Tuning file: " + obj.tuningFile;
      fileLabel.color = "black";
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
        fileLabel.color = "black";
        writeSettings({tuningFile: "" + fileDialog.fileUrl});
    }
    onRejected: {
    }
  }
  FileIO {
    id: "tuningFile"
    onError: {
      debugLog(msg);
    }
  }
  FileIO {
    id: "settingsFile"
    source: homePath() + "/.musescore-xentuner-settings.json"
    onError: {
      debugLog(msg);
    }
  }
  FileIO {
    id: "debugFile"
    source: homePath() + "/.musescore-xentuner-log.txt"
    onError: {
      console.log(msg); // can't use debugLog since it won't work
    }
  }
  onRun: {
  }
  Component.onCompleted: {
    if (mscoreMajorVersion >= 4) {
        title = qsTr("XenTuner")
        categoryCode = "playback"
    }

    if (settingsFile.exists()) {
      loadSettings();
    } else {
      fileLabel.text = "No file selected";
    }
  }

      // from addCourtesyAccidentals.qml, GPLv3

      // if nothing is selected process whole score
      property bool processAll: false

      // function getEndStaffOfPart
      //
      // return the first staff that does not belong to
      // the part containing given start staff.

      function getEndStaffOfPart(startStaff) {
            var startTrack = startStaff * 4;
            var parts = curScore.parts;

            for(var i = 0; i < parts.length; i++) {
                  var part = parts[i];

                  if( (part.startTrack <= startTrack)
                        && (part.endTrack > startTrack) ) {
                        return(part.endTrack/4);
                  }
            }

            // not found!
            debugLog("error: part for " + startStaff + " not found!");
            qtQuit();
      }

      // function processPart
      //
      // do the actual work: process all given tracks in parallel
      //
      // We go through all tracks simultaneously, because we also want to tune
      // accidentals for notes of different voices in the same octave

      function processPart(cursor,endTick,startTrack,endTrack,tuningData) {
            if(processAll) {
                  // we need to reset track first, otherwise
                  // rewind(0) doesn't work correctly
                  cursor.track=0;
                  cursor.rewind(0);
            } else {
                  cursor.rewind(1);
            }

            var segment = cursor.segment;

            // we use the cursor to know measure boundaries
            cursor.nextMeasure();

            var curMeasureArray = new Array();

            // we use a segment, because the cursor always proceeds to
            // the next element in the given track and we don't know
            // in which track the element is.
            var inLastMeasure=false;
            while(segment && (processAll || segment.tick < endTick)) {
                  // check if still inside same measure
                  if(!inLastMeasure && !(segment.tick < cursor.tick)) {
                        // new measure
                        curMeasureArray = new Array();
                        if(!cursor.nextMeasure()) {
                              inLastMeasure=true;
                        }
                  }

                  for(var track=startTrack; track<endTrack; track++) {

                        // look for notes and grace notes
                        if(segment.elementAt(track) && segment.elementAt(track).type == Element.CHORD) {
                              // process graceNotes if present
                              if(segment.elementAt(track).graceNotes.length > 0) {
                                    var graceChords = segment.elementAt(track).graceNotes;

                                    for(var j=0;j<graceChords.length;j++) {
                                          var notes = graceChords[j].notes;
                                          for(var i=0;i<notes.length;i++) {
                                                processNote(notes[i],curMeasureArray,tuningData);
                                          }
                                    }
                              }

                              // process notes
                              var notes = segment.elementAt(track).notes;

                              for(var i=0;i<notes.length;i++) {
                                    processNote(notes[i],curMeasureArray,tuningData);
                              }
                        }
                  }
                  segment=segment.next;
            }
      }

      function processSelection(tuningData) {
            debugLog("start process selection");

            curScore.startCmd();

             if (typeof curScore === 'undefined' || curScore == null) {
                   debugLog("error: no score!");
                   qtQuit();
             }

            // find selection
            var startStaff;
            var endStaff;
            var endTick;

            var cursor = curScore.newCursor();
            cursor.rewind(1);
            if(!cursor.segment) {
                  // no selection
                  debugLog("no selection: processing whole score");
                  processAll = true;
                  startStaff = 0;
                  endStaff = curScore.nstaves;
            } else {
                  startStaff = cursor.staffIdx;
                  cursor.rewind(2);
                  endStaff = cursor.staffIdx+1;
                  endTick = cursor.tick;
                  if(endTick == 0) {
                        // selection includes end of score
                        // calculate tick from last score segment
                        endTick = curScore.lastSegment.tick + 1;
                  }
                  cursor.rewind(1);
                  debugLog("Selection is: Staves("+startStaff+"-"+endStaff+") Ticks("+cursor.tick+"-"+endTick+")");
            }

            debugLog("ProcessAll is "+processAll);

            // go through all staves of a part simultaneously
            // find staves that belong to the same part

            var curStartStaff = startStaff;

            while(curStartStaff < endStaff) {
                  // find end staff for this part
                  var curEndStaff = getEndStaffOfPart(curStartStaff);

                  if(curEndStaff > endStaff) {
                        curEndStaff = endStaff;
                  }

                  // do the work
                  processPart(cursor,endTick,curStartStaff*4,curEndStaff*4,tuningData);

                  // next part
                  curStartStaff = curEndStaff;
            }

            //curScore.doLayout();
            curScore.endCmd();

            debugLog("end process selection");
      }
  function qtQuit() {
    (typeof(quit) === 'undefined' ? Qt.quit : quit)();
  }
  function debugLog(msg) {
    var prevContent = debugFile.read();
    debugFile.write(prevContent + msg + '\n');
  }
}
