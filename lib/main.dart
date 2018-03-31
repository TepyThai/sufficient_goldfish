import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;

import 'dart:convert';


import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:audioplayer/audioplayer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart' show rootBundle;


void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Plenty of Goldfish',
      theme: new ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: new ProfilePage(),
    );
  }
}

enum Field { name, favoriteMusic, phValue, profilePicture }

// we may decide not to do this part since a close variant is shown in our other talk.
class _ProfilePageState extends State<ProfilePage> {
  File _imageFile;
  DocumentReference _profile;
  bool _editing;
  Map<String, dynamic> _localValues;
  static String defaultPicturePath = 'assets/longhorn-cowfish.jpg';

  @override
  void initState() {
    super.initState();
    _profile = Firestore.instance.collection('profiles').document();
    _editing = false;
    _localValues = {};
  }

  getImage() async {
    var imageFile = await ImagePicker.pickImage();
    await _uploadToStorage(imageFile);
    setState(() {
      _imageFile = imageFile;
    });
  }

  Future<Null> _uploadToStorage(File imageFile) async {
    var random = new Random().nextInt(10000);
    var ref = FirebaseStorage.instance.ref().child('image_$random.jpg');
    var uploadTask = ref.put(imageFile);
    var downloadUrl = (await uploadTask.future).downloadUrl;
    _updateLocalData(Field.profilePicture, downloadUrl);
  }

  void _updateLocalData(Field field, value) {
    setState(() {
      _localValues[field.toString()] = value;
    });
  }

  Future<Null> _updateProfile() async {
    /*if(_imageFile == null) {
      ByteData data = await rootBundle.load(defaultPicturePath);
      _uploadToStorage(new File(defaultPicturePath)); // TODO.
    }*/
    _profile.setData(_localValues, SetOptions.merge);
  }

  Widget _showProfilePicture() {
    Image image = _imageFile == null
        ? new Image.asset(defaultPicturePath)
        : new Image.file(_imageFile);
    if (_editing) {
      return new Stack(
        children: [
          new Container(
            child: image,
            foregroundDecoration: new BoxDecoration(
                color: new Color.fromRGBO(200, 200, 200, 0.5)),
          ),
          new IconButton(
            iconSize: 50.0,
            onPressed: getImage,
            tooltip: 'Pick Image',
            icon: new Icon(Icons.add_a_photo),
          ),
        ],
        alignment: new Alignment(0.0, 0.0),
      );
    } else {
      return image;
    }
  }

  Widget _showData(Field field) {
    String label;
    String defaultValue;
    String currentValue = _localValues[field.toString()];
    switch (field) {
      case Field.name:
        label = 'Name';
        defaultValue = 'Frank';
        break;
      case Field.favoriteMusic:
        label = 'Favorite Music';
        defaultValue = 'Blubstep';
        break;
      case Field.phValue:
        label = 'Favorite pH level';
        defaultValue = '5';
        break;
      default:
        break;
    }
    if (_editing) {
      return new TextField(
        decoration: new InputDecoration(labelText: label),
        onChanged: (changed) => _updateLocalData(field, changed),
        controller:
            new TextEditingController(text: currentValue ?? defaultValue),
      );
    } else {
      _localValues[field.toString()] = currentValue ?? defaultValue;
      return new Text('$label: ${currentValue ?? defaultValue}');
    }
  }

  MatchData _getMatchData() {
    return new MatchData.generate();
  }

  // TODO(efortuna): Maybe do something prettier here with StreamBuilder like the cloud firestore example.
  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        floatingActionButton: new IconButton(
          onPressed: () {
            _updateProfile();
            setState(() {
              _editing = !_editing;
            });
          },
          tooltip: _editing ? 'Edit Profile' : 'Save Changes',
          icon: new Icon(_editing ? Icons.check : Icons.edit),
        ),
        body: new ListView(
          children: <Widget>[
            _showProfilePicture(),
            _showData(Field.name),
            _showData(Field.favoriteMusic),
            _showData(Field.phValue),
            new Center(
                child: new RaisedButton(
                    onPressed: matchFish,
                    child: new Text("Find your fish!"))),
          ],
        ));
  }

  testStuff() async {
    QuerySnapshot queryResult = await Firestore.instance.collection('profiles').getDocuments();
    List<DocumentSnapshot> profiles = queryResult.documents;
    DocumentSnapshot match = profiles[new Random().nextInt(profiles.length)];

    print(json.encode(match.data));
  }

  matchFish() {
    http.get('https://us-central1-sufficientgoldfish.cloudfunctions.net/matchFish?id=12345&id=5654&id=222')
        .then((fileContents) {
          print('contents ${fileContents.body}');
    });

    testStuff();


    Navigator.of(context).push(new MaterialPageRoute<Null>(
        builder: (BuildContext context) {
          return new MatchPage(_getMatchData());
        }));

  }
}

class ProfilePage extends StatefulWidget {
  _ProfilePageState createState() => new _ProfilePageState();
}

typedef void LocationCallback(Map<String, double> location);

class LocationTools {
  final Location location = new Location();

  Future<Map<String, double>> getLocation() {
    return location.getLocation;
  }

  void initListener(LocationCallback callback) {
    location.onLocationChanged.listen((Map<String, double> currentLocation) {
      callback(currentLocation);
    });
  }
}

class MatchPage extends StatelessWidget {
  final MatchData matchData;

  MatchPage(this.matchData);

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: new AppBar(
          title: new Text("You've got a fish!"),
        ),
        body: new Column(
          children: [
            new Image.asset(matchData.profilePicture),
            new Text("Name: ${matchData.name}"),
            new Text("Favorite Music: ${matchData.favoriteMusic}"),
            new Text("Favorite pH: ${matchData.favoritePh}"),
            new Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  new FlatButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: new Text("Reject")),
                  new FlatButton(
                      onPressed: () {
                        Navigator.of(context).push(new MaterialPageRoute<Null>(
                            builder: (BuildContext context) {
                          return new FinderPage(matchData.targetLatitude,
                              matchData.targetLongitude);
                        }));
                      },
                      child: new Text("Accept")),
                ]),
          ],
        ));
  }
}

class FinderPage extends StatefulWidget {
  final double targetLatitude;
  final double targetLongitude;

  FinderPage(this.targetLatitude, this.targetLongitude);

  @override
  _FinderPageState createState() => new _FinderPageState();
}

class _FinderPageState extends State<FinderPage> {
  LocationTools locationTools;
  double latitude = 0.0;
  double longitude = 0.0;
  double accuracy = 0.0;

  final searchingAudio =
      'https://freesound.org/data/previews/28/28693_98464-lq.mp3';
  final foundAudio =
      'https://freesound.org/data/previews/397/397354_4284968-lq.mp3';

  AudioPlayer audioPlayer = new AudioPlayer();

  void _initAudio(String loopFile) {
    // restart audio if it has finished
    audioPlayer.setCompletionHandler(() {
      audioPlayer.play(loopFile);
    });
    // restart audio if it has been playing for at least 3 seconds
    audioPlayer.setPositionHandler((Duration d) {
      if (d.inSeconds > 3) {
        _playNewAudio(loopFile);
      }
    });
    audioPlayer.play(loopFile);
  }

  void _playNewAudio(String audioFile) {
    audioPlayer.stop().then((result) {
      audioPlayer.play(audioFile);
    });
  }

  void _resetHandlers() {
    audioPlayer.setCompletionHandler(() {});
    audioPlayer.setPositionHandler((Duration d) {});
  }

  _FinderPageState() {
    locationTools = new LocationTools();
    locationTools.getLocation().then((Map<String, double> currentLocation) {
      _updateLocation(currentLocation);
    });
    locationTools.initListener(_updateLocation);
    _initAudio(searchingAudio);
  }

  void _updateLocation(Map<String, double> currentLocation) {
    setState(() {
      latitude = currentLocation["latitude"];
      longitude = currentLocation["longitude"];
      accuracy = currentLocation["accuracy"];
    });
  }

  double _getLocationDiff() {
    int milesBetweenLines = 69;
    int feetInMile = 5280;
    int desiredFeetRange = 15;
    double multiplier = 2 * milesBetweenLines * feetInMile / desiredFeetRange;
    double latitudeDiff = (latitude - widget.targetLatitude).abs() * multiplier;
    double longitudeDiff =
        (longitude - widget.targetLongitude).abs() * multiplier;
    if (latitudeDiff > 1) {
      latitudeDiff = 1.0;
    }
    if (longitudeDiff > 1) {
      longitudeDiff = 1.0;
    }
    double diff = (latitudeDiff + longitudeDiff) / 2;
    if (diff < 0.1) {
      _resetHandlers();
      _playNewAudio(foundAudio);
    }
    return diff;
  }

  Color _colorFromLocationDiff() {
    return Color.lerp(Colors.red, Colors.blue, _getLocationDiff());
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: new AppBar(
          title: new Text("Find your fish!"),
        ),
        body: new Container(
          color: _colorFromLocationDiff(),
          child: new Center(
            child: new Image.asset('assets/location_ping.gif'),
          ),
        ));
  }
}

class MatchData {
  String profilePicture; //TODO: Probably switch this to a File
  String name;
  String favoriteMusic;
  int favoritePh;
  double targetLatitude;
  double targetLongitude;

  // TODO: Populate this via Firebase
  MatchData.generate() {
    profilePicture = 'assets/koi.jpg';
    name = 'Finnegan';
    favoriteMusic = 'Goldies';
    favoritePh = 7;
    targetLatitude = 37.785844;
    targetLongitude = -122.406427;
  }
}
