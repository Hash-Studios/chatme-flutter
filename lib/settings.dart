import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import './const.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './theme_provider.dart';
import 'package:provider/provider.dart';

class Settings extends StatefulWidget {
  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<DynamicTheme>(context);
    return new Scaffold(
      backgroundColor: themeProvider.isDarkMode?lightPrimaryColorL:lightPrimaryColorD,
      appBar: new AppBar(
        title: new Text(
          'Settings',
          style: TextStyle(
            color: themeProvider.isDarkMode?textIconsColorL:textIconsColorD,
          ),
        ),
        actions: <Widget>[
          IconButton(
              icon: Icon(Icons.brightness_4),
              onPressed: () {
                setState(() {
                  themeProvider.changeDarkMode(!themeProvider.isDarkMode);
                });
              })
        ],
      ),
      body: new SettingsScreen(),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  @override
  State createState() => new SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  TextEditingController controllerNickname;
  TextEditingController controllerAboutMe;

  SharedPreferences prefs;

  String id = '';
  String nickname = '';
  String aboutMe = '';
  String photoUrl = '';

  bool isLoading = false;
  File avatarImageFile;

  final FocusNode focusNodeNickname = new FocusNode();
  final FocusNode focusNodeAboutMe = new FocusNode();

  @override
  void initState() {
    super.initState();
    readLocal();
  }

  void readLocal() async {
    prefs = await SharedPreferences.getInstance();
    id = prefs.getString('id') ?? '';
    nickname = prefs.getString('nickname') ?? '';
    aboutMe = prefs.getString('aboutMe') ?? '';
    photoUrl = prefs.getString('photoUrl') ?? '';

    controllerNickname = new TextEditingController(text: nickname);
    controllerAboutMe = new TextEditingController(text: aboutMe);

    // Force refresh input
    setState(() {});
  }

  Future getImage() async {
    File image = await ImagePicker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        avatarImageFile = image;
        isLoading = true;
      });
    }
    uploadFile();
  }

  Future uploadFile() async {
    String fileName = id;
    StorageReference reference = FirebaseStorage.instance.ref().child(fileName);
    StorageUploadTask uploadTask = reference.putFile(avatarImageFile);
    StorageTaskSnapshot storageTaskSnapshot;
    uploadTask.onComplete.then((value) {
      if (value.error == null) {
        storageTaskSnapshot = value;
        storageTaskSnapshot.ref.getDownloadURL().then((downloadUrl) {
          photoUrl = downloadUrl;
          Firestore.instance.collection('users').document(id).updateData({
            'nickname': nickname,
            'aboutMe': aboutMe,
            'photoUrl': photoUrl
          }).then((data) async {
            await prefs.setString('photoUrl', photoUrl);
            setState(() {
              isLoading = false;
            });
            Fluttertoast.showToast(msg: "Profile Photo changed successfully");
          }).catchError((err) {
            setState(() {
              isLoading = false;
            });
            Fluttertoast.showToast(msg: err.toString());
          });
        }, onError: (err) {
          setState(() {
            isLoading = false;
          });
          Fluttertoast.showToast(msg: "Can't change profile photo");
        });
      } else {
        setState(() {
          isLoading = false;
        });
        Fluttertoast.showToast(msg: "Can't change profile photo");
      }
    }, onError: (err) {
      setState(() {
        isLoading = false;
      });
      Fluttertoast.showToast(msg: err.toString());
    });
  }

  void handleUpdateData() {
    focusNodeNickname.unfocus();
    focusNodeAboutMe.unfocus();

    setState(() {
      isLoading = true;
    });

    Firestore.instance.collection('users').document(id).updateData({
      'nickname': nickname,
      'aboutMe': aboutMe,
      'photoUrl': photoUrl
    }).then((data) async {
      await prefs.setString('nickname', nickname);
      await prefs.setString('aboutMe', aboutMe);
      await prefs.setString('photoUrl', photoUrl);

      setState(() {
        isLoading = false;
      });

      Fluttertoast.showToast(msg: "Updated info successfully");
    }).catchError((err) {
      setState(() {
        isLoading = false;
      });

      Fluttertoast.showToast(msg: err.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<DynamicTheme>(context);
    return Stack(
      children: <Widget>[
        SingleChildScrollView(
          child: Column(
            children: <Widget>[
              // Avatar
              Container(
                child: Center(
                  child: Stack(
                    children: <Widget>[
                      (avatarImageFile == null)
                          ? (photoUrl != ''
                              ? Material(
                                  child: CachedNetworkImage(
                                    placeholder: (context, url) => Container(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.0,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                themeProvider.isDarkMode?darkPrimaryColorL:darkPrimaryColorD),
                                      ),
                                      width: 90.0,
                                      height: 90.0,
                                      padding: EdgeInsets.all(20.0),
                                    ),
                                    imageUrl: photoUrl,
                                    width: 90.0,
                                    height: 90.0,
                                    fit: BoxFit.cover,
                                  ),
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(45.0)),
                                  clipBehavior: Clip.hardEdge,
                                )
                              : Icon(
                                  Icons.account_circle,
                                  size: 90.0,
                                  color: themeProvider.isDarkMode?textIconsColorL:textIconsColorD,
                                ))
                          : Material(
                              child: Image.file(
                                avatarImageFile,
                                width: 90.0,
                                height: 90.0,
                                fit: BoxFit.cover,
                              ),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(45.0)),
                              clipBehavior: Clip.hardEdge,
                            ),
                      IconButton(
                        icon: Icon(
                          Icons.camera_alt,
                          color: themeProvider.isDarkMode?textIconsColorL:textIconsColorD.withOpacity(0.5),
                        ),
                        onPressed: getImage,
                        padding: EdgeInsets.all(30.0),
                        splashColor: Colors.transparent,
                        highlightColor: themeProvider.isDarkMode?textIconsColorL:textIconsColorD,
                        iconSize: 30.0,
                      ),
                    ],
                  ),
                ),
                width: double.infinity,
                margin: EdgeInsets.all(20.0),
              ),

              // Input
              Container(
                decoration: BoxDecoration(
                    color: themeProvider.isDarkMode?rightTextColorL:rightTextColorD,
                    borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 25),
                  child: Column(
                    children: <Widget>[
                      // Username
                      Container(
                        child: Text(
                          'Name',
                          style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.isDarkMode?darkPrimaryColorL:darkPrimaryColorD),
                        ),
                        margin:
                            EdgeInsets.only(left: 10.0, bottom: 5.0, top: 10.0),
                      ),
                      Container(
                        child: Theme(
                          data: Theme.of(context)
                              .copyWith(primaryColor: themeProvider.isDarkMode?primaryColorL:primaryColorD),
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'User Name',
                              contentPadding: new EdgeInsets.all(5.0),
                              hintStyle: TextStyle(color: themeProvider.isDarkMode?darkPrimaryColorL:darkPrimaryColorD),
                            ),
                            controller: controllerNickname,
                            onChanged: (value) {
                              nickname = value;
                            },
                            focusNode: focusNodeNickname,
                          ),
                        ),
                        margin: EdgeInsets.only(left: 30.0, right: 30.0),
                      ),

                      // About me
                      Container(
                        child: Text(
                          'About me',
                          style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.isDarkMode?darkPrimaryColorL:darkPrimaryColorD),
                        ),
                        margin:
                            EdgeInsets.only(left: 10.0, top: 30.0, bottom: 5.0),
                      ),
                      Container(
                        child: Theme(
                          data: Theme.of(context)
                              .copyWith(primaryColor: themeProvider.isDarkMode?primaryColorL:primaryColorD),
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Write your bio here...',
                              contentPadding: EdgeInsets.all(5.0),
                              hintStyle: TextStyle(color: themeProvider.isDarkMode?darkPrimaryColorL:darkPrimaryColorD),
                            ),
                            controller: controllerAboutMe,
                            onChanged: (value) {
                              aboutMe = value;
                            },
                            focusNode: focusNodeAboutMe,
                          ),
                        ),
                        margin: EdgeInsets.only(left: 30.0, right: 30.0),
                      ),
                    ],
                    crossAxisAlignment: CrossAxisAlignment.start,
                  ),
                ),
              ),

              // Button
              Container(
                child: FlatButton(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  onPressed: handleUpdateData,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.check,
                        size: 30,
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Text(
                        'Done',
                        style: TextStyle(fontSize: 20.0),
                      ),
                    ],
                  ),
                  color: themeProvider.isDarkMode?primaryColorL:primaryColorD,
                  highlightColor: new Color(0xff8d93a0),
                  splashColor: Colors.transparent,
                  textColor: themeProvider.isDarkMode?rightTextColorL:rightTextColorD,
                  padding: EdgeInsets.fromLTRB(30.0, 10.0, 30.0, 10.0),
                ),
                margin: EdgeInsets.only(top: 50.0, bottom: 50.0),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  SizedBox(
                    height: 200,
                  ),
                  Text('www.codenameakshay.tech',style: TextStyle(color: themeProvider.isDarkMode?darkPrimaryColorL:darkPrimaryColorD),)
                ],
              )
            ],
          ),
          padding: EdgeInsets.only(left: 15.0, right: 15.0),
        ),

        // Loading
        Positioned(
          child: isLoading
              ? Container(
                  child: Center(
                    child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(themeProvider.isDarkMode?darkPrimaryColorL:darkPrimaryColorD)),
                  ),
                  color: Colors.white.withOpacity(0.8),
                )
              : Container(),
        ),
      ],
    );
  }
}
