import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import './const.dart';
import './fullPhoto.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:giphy_picker/giphy_picker.dart';
import 'package:giphy_client/giphy_client.dart';
import './theme_provider.dart';
import 'package:provider/provider.dart';

class Chat extends StatelessWidget {
  final String peerId;
  final String peerAvatar;
  final String peerName;
  bool peerStatus;

  Chat(
      {Key key,
      @required this.peerId,
      @required this.peerAvatar,
      @required this.peerName,
      @required this.peerStatus})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<DynamicTheme>(context);
    return new Scaffold(
      backgroundColor:
          themeProvider.isDarkMode ? lightPrimaryColorL : lightPrimaryColorD,
      appBar: new AppBar(
        title: new Text(
          '$peerName ${peerStatus?"Online":"Offline"}',
          style: TextStyle(
              color:
                  themeProvider.isDarkMode ? textIconsColorL : textIconsColorD,
              fontWeight: FontWeight.bold),
        ),
      ),
      body: new ChatScreen(
        peerId: peerId,
        peerAvatar: peerAvatar,
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String peerId;
  final String peerAvatar;

  ChatScreen({Key key, @required this.peerId, @required this.peerAvatar})
      : super(key: key);

  @override
  State createState() =>
      new ChatScreenState(peerId: peerId, peerAvatar: peerAvatar);
}

class ChatScreenState extends State<ChatScreen> {
  ChatScreenState({Key key, @required this.peerId, @required this.peerAvatar});

  String peerId;
  String peerAvatar;
  String id;

  GiphyGif gif;
  String gifURL;
  File gifFile;

  var listMessage;
  String groupChatId;
  SharedPreferences prefs;

  File imageFile;
  bool isLoading;
  bool isShowSticker;
  String imageUrl;

  final TextEditingController textEditingController =
      new TextEditingController();
  final ScrollController listScrollController = new ScrollController();
  final FocusNode focusNode = new FocusNode();

  @override
  void initState() {
    super.initState();
    focusNode.addListener(onFocusChange);

    groupChatId = '';

    isLoading = false;
    isShowSticker = false;
    imageUrl = '';

    readLocal();
  }

  void onFocusChange() {
    if (focusNode.hasFocus) {
      // Hide sticker when keyboard appear
      setState(() {
        isShowSticker = false;
      });
    }
  }

  readLocal() async {
    prefs = await SharedPreferences.getInstance();
    id = prefs.getString('id') ?? '';
    if (id.hashCode <= peerId.hashCode) {
      groupChatId = '$id-$peerId';
    } else {
      groupChatId = '$peerId-$id';
    }

    Firestore.instance
        .collection('users')
        .document(id)
        .updateData({'chattingWith': peerId, 'online': true});

    setState(() {});
  }

  Future getImage() async {
    imageFile = await ImagePicker.pickImage(source: ImageSource.gallery);

    if (imageFile != null) {
      setState(() {
        isLoading = true;
      });
      uploadFile();
    }
  }

  Future getImageCamera() async {
    imageFile = await ImagePicker.pickImage(source: ImageSource.camera);

    if (imageFile != null) {
      setState(() {
        isLoading = true;
      });
      uploadFile();
    }
  }

  void getSticker() {
    // Hide keyboard when sticker appear
    focusNode.unfocus();
    setState(() {
      isShowSticker = !isShowSticker;
    });
  }

  Future getGIF() async {
    gif = await GiphyPicker.pickGif(
            showPreviewPage: false,
            context: context,
            apiKey: 'Giphy api key')
        .then((value) {
      gifURL = value.images.original.url;
      // print(gifURL);
    }, onError: (e) {
      print(e);
    });
    if (gifURL != null) {
      setState(() {
        isLoading = true;
      });
      uploadGIF();
    }
  }

  Future uploadFile() async {
    String fileName = DateTime.now().millisecondsSinceEpoch.toString();
    StorageReference reference = FirebaseStorage.instance.ref().child(fileName);
    StorageUploadTask uploadTask = reference.putFile(imageFile);
    StorageTaskSnapshot storageTaskSnapshot = await uploadTask.onComplete;
    storageTaskSnapshot.ref.getDownloadURL().then((downloadUrl) {
      imageUrl = downloadUrl;
      setState(() {
        isLoading = false;
        onSendMessage(imageUrl, 1);
      });
    }, onError: (err) {
      setState(() {
        isLoading = false;
      });
      Fluttertoast.showToast(msg: 'This file is not an image');
    });
  }

  Future uploadGIF() async {
    // String fileName = DateTime.now().millisecondsSinceEpoch.toString();
    // StorageReference reference = FirebaseStorage.instance.ref().child(fileName);
    // StorageUploadTask uploadTask = reference.putFile(imageFile);
    // StorageTaskSnapshot storageTaskSnapshot = await uploadTask.onComplete;
    // storageTaskSnapshot.ref.getDownloadURL().then((downloadUrl) {
    // gifURL = ;
    setState(() {
      isLoading = false;
      onSendMessage(gifURL, 3);
    });
    // }, onError: (err) {
    //   setState(() {
    //     isLoading = false;
    //   });
    //   Fluttertoast.showToast(msg: 'This GIF cannot be used');
    // });
  }

  void onSendMessage(String content, int type) {
    // type: 0 = text, 1 = image, 2 = sticker, 3 = gif
    if (content.trim() != '') {
      textEditingController.clear();

      var documentReference = Firestore.instance
          .collection('messages')
          .document(groupChatId)
          .collection(groupChatId)
          .document(DateTime.now().millisecondsSinceEpoch.toString());

      Firestore.instance.runTransaction((transaction) async {
        await transaction.set(
          documentReference,
          {
            'idFrom': id,
            'idTo': peerId,
            'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
            'content': content,
            'type': type
          },
        );
      });
      listScrollController.animateTo(0.0,
          duration: Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      Fluttertoast.showToast(msg: 'Nothing to send');
    }
  }

  Widget buildItem(int index, DocumentSnapshot document) {
    final themeProvider = Provider.of<DynamicTheme>(context);
    if (document['idFrom'] == id) {
      // Right (my message)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Row(
            children: <Widget>[
              document['type'] == 0
                  // Text
                  ? Container(
                      child: Text(
                        document['content'],
                        style: TextStyle(
                            color: themeProvider.isDarkMode
                                ? darkPrimaryColorL
                                : darkPrimaryColorD),
                      ),
                      padding: EdgeInsets.fromLTRB(15.0, 10.0, 15.0, 10.0),
                      width: 200.0,
                      decoration: BoxDecoration(
                          color: themeProvider.isDarkMode
                              ? rightTextColorL
                              : rightTextColorD,
                          borderRadius: BorderRadius.circular(8.0)),
                      margin: EdgeInsets.only(
                          bottom: isLastMessageRight(index) ? 0.0 : 0.0,
                          right: 10.0),
                    )
                  : document['type'] == 1
                      // Image
                      ? Container(
                          child: FlatButton(
                            child: Material(
                              child: CachedNetworkImage(
                                placeholder: (context, url) => Hero(
                                  tag: "img$url",
                                  child: Container(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          themeProvider.isDarkMode
                                              ? darkPrimaryColorL
                                              : darkPrimaryColorD),
                                    ),
                                    width: 200.0,
                                    height: 200.0,
                                    padding: EdgeInsets.all(70.0),
                                    decoration: BoxDecoration(
                                      color: themeProvider.isDarkMode
                                          ? lightPrimaryColorL
                                          : lightPrimaryColorD,
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(8.0),
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Material(
                                  child: Image.asset(
                                    'assets/images/img_not_available.jpeg',
                                    width: 200.0,
                                    height: 200.0,
                                    fit: BoxFit.cover,
                                  ),
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(8.0),
                                  ),
                                  clipBehavior: Clip.hardEdge,
                                ),
                                imageUrl: document['content'],
                                width: 200.0,
                                height: 200.0,
                                fit: BoxFit.cover,
                              ),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8.0)),
                              clipBehavior: Clip.hardEdge,
                            ),
                            onPressed: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          FullPhoto(url: document['content'])));
                            },
                            padding: EdgeInsets.all(0),
                          ),
                          margin: EdgeInsets.only(
                              bottom: isLastMessageRight(index) ? 0.0 : 0.0,
                              right: 10.0),
                        )
                      // Sticker
                      : document['type'] == 2
                          ? Container(
                              child: new Image.asset(
                                'assets/images/${document['content']}.gif',
                                width: 100.0,
                                height: 100.0,
                                fit: BoxFit.cover,
                              ),
                              margin: EdgeInsets.only(
                                  bottom:
                                      isLastMessageRight(index) ? 00.0 : 0.0,
                                  right: 10.0),
                            )
                          : Container(
                              //giphy gifs
                              child: FlatButton(
                                child: Material(
                                  child: CachedNetworkImage(
                                    placeholder: (context, url) => Hero(
                                      tag: "img$url",
                                      child: Container(
                                        child: CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  themeProvider.isDarkMode
                                                      ? darkPrimaryColorL
                                                      : darkPrimaryColorD),
                                        ),
                                        width: 200.0,
                                        height: 200.0,
                                        padding: EdgeInsets.all(70.0),
                                        decoration: BoxDecoration(
                                          color: themeProvider.isDarkMode
                                              ? lightPrimaryColorL
                                              : lightPrimaryColorD,
                                          borderRadius: BorderRadius.all(
                                            Radius.circular(8.0),
                                          ),
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Material(
                                      child: Image.asset(
                                        'assets/images/img_not_available.jpeg',
                                        width: 200.0,
                                        height: 200.0,
                                        fit: BoxFit.cover,
                                      ),
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(8.0),
                                      ),
                                      clipBehavior: Clip.hardEdge,
                                    ),
                                    imageUrl: document['content'],
                                    width: 200.0,
                                    // height: 200.0,
                                    fit: BoxFit.cover,
                                  ),
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(8.0)),
                                  clipBehavior: Clip.hardEdge,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => FullPhoto(
                                              url: document['content'])));
                                },
                                padding: EdgeInsets.all(0),
                              ),
                              margin: EdgeInsets.only(
                                  bottom: isLastMessageRight(index) ? 0.0 : 0.0,
                                  right: 10.0),
                            ),
            ],
            mainAxisAlignment: MainAxisAlignment.end,
          ),
          Container(
            child: Text(
              DateFormat('kk:mm').format(DateTime.fromMillisecondsSinceEpoch(
                  int.parse(document['timestamp']))),
              style: TextStyle(
                  color: themeProvider.isDarkMode
                      ? darkPrimaryColorL
                      : darkPrimaryColorD,
                  fontSize: 12.0,
                  fontStyle: FontStyle.italic),
            ),
            margin: EdgeInsets.only(
                left: 0.0,
                top: 5.0,
                right: 10,
                bottom: isLastMessageRight(index) ? 20 : 10),
          ),
        ],
      );
    } else {
      // Left (peer message)
      return Container(
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                isLastMessageLeft(index)
                    ? Material(
                        child: CachedNetworkImage(
                          placeholder: (context, url) => Container(
                            child: CircularProgressIndicator(
                              strokeWidth: 1.0,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  themeProvider.isDarkMode
                                      ? darkPrimaryColorL
                                      : darkPrimaryColorD),
                            ),
                            width: 35.0,
                            height: 35.0,
                            padding: EdgeInsets.all(10.0),
                          ),
                          imageUrl: peerAvatar,
                          width: 35.0,
                          height: 35.0,
                          fit: BoxFit.cover,
                        ),
                        borderRadius: BorderRadius.all(
                          Radius.circular(18.0),
                        ),
                        clipBehavior: Clip.hardEdge,
                      )
                    : Container(width: 35.0),
                document['type'] == 0
                    ? Container(
                        child: Text(
                          document['content'],
                          style: TextStyle(
                              color: themeProvider.isDarkMode
                                  ? secondaryTextColorL
                                  : secondaryTextColorD),
                        ),
                        padding: EdgeInsets.fromLTRB(15.0, 10.0, 15.0, 10.0),
                        width: 200.0,
                        decoration: BoxDecoration(
                            color: themeProvider.isDarkMode
                                ? primaryColorL
                                : primaryColorD,
                            borderRadius: BorderRadius.circular(8.0)),
                        margin: EdgeInsets.only(left: 10.0),
                      )
                    : document['type'] == 1
                        ? Container(
                            child: FlatButton(
                              child: Material(
                                child: CachedNetworkImage(
                                  placeholder: (context, url) => Container(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          themeProvider.isDarkMode
                                              ? darkPrimaryColorL
                                              : darkPrimaryColorD),
                                    ),
                                    width: 200.0,
                                    height: 200.0,
                                    padding: EdgeInsets.all(70.0),
                                    decoration: BoxDecoration(
                                      color: themeProvider.isDarkMode
                                          ? lightPrimaryColorL
                                          : lightPrimaryColorD,
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(8.0),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Material(
                                    child: Image.asset(
                                      'assets/images/img_not_available.jpeg',
                                      width: 200.0,
                                      height: 200.0,
                                      fit: BoxFit.cover,
                                    ),
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(8.0),
                                    ),
                                    clipBehavior: Clip.hardEdge,
                                  ),
                                  imageUrl: document['content'],
                                  width: 200.0,
                                  height: 200.0,
                                  fit: BoxFit.cover,
                                ),
                                borderRadius:
                                    BorderRadius.all(Radius.circular(8.0)),
                                clipBehavior: Clip.hardEdge,
                              ),
                              onPressed: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => FullPhoto(
                                            url: document['content'])));
                              },
                              padding: EdgeInsets.all(0),
                            ),
                            margin: EdgeInsets.only(left: 10.0),
                          )
                        : document['type'] == 2
                            ? Container(
                                child: new Image.asset(
                                  'assets/images/${document['content']}.gif',
                                  width: 100.0,
                                  height: 100.0,
                                  fit: BoxFit.cover,
                                ),
                                margin: EdgeInsets.only(
                                    bottom:
                                        isLastMessageRight(index) ? 20.0 : 10.0,
                                    right: 10.0),
                              )
                            : Container(
                                //giphy gifs
                                child: FlatButton(
                                  child: Material(
                                    child: CachedNetworkImage(
                                      placeholder: (context, url) => Hero(
                                        tag: "img$url",
                                        child: Container(
                                          child: CircularProgressIndicator(
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    themeProvider.isDarkMode
                                                        ? darkPrimaryColorL
                                                        : darkPrimaryColorD),
                                          ),
                                          width: 200.0,
                                          height: 200.0,
                                          padding: EdgeInsets.all(70.0),
                                          decoration: BoxDecoration(
                                            color: themeProvider.isDarkMode
                                                ? lightPrimaryColorL
                                                : lightPrimaryColorD,
                                            borderRadius: BorderRadius.all(
                                              Radius.circular(8.0),
                                            ),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Material(
                                        child: Image.asset(
                                          'assets/images/img_not_available.jpeg',
                                          width: 200.0,
                                          height: 200.0,
                                          fit: BoxFit.cover,
                                        ),
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(8.0),
                                        ),
                                        clipBehavior: Clip.hardEdge,
                                      ),
                                      imageUrl: document['content'],
                                      width: 200.0,
                                      // height: 200.0,
                                      fit: BoxFit.cover,
                                    ),
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(8.0)),
                                    clipBehavior: Clip.hardEdge,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) => FullPhoto(
                                                url: document['content'])));
                                  },
                                  padding: EdgeInsets.all(0),
                                ),
                                margin: EdgeInsets.only(
                                    bottom:
                                        isLastMessageRight(index) ? 0.0 : 0.0,
                                    left: 10.0),
                              ),
              ],
            ),
            Container(
              child: Text(
                isLastMessageLeft(index)
                    ? DateFormat('dd MMM kk:mm').format(
                        DateTime.fromMillisecondsSinceEpoch(
                            int.parse(document['timestamp'])))
                    : DateFormat('kk:mm').format(
                        DateTime.fromMillisecondsSinceEpoch(
                            int.parse(document['timestamp']))),
                style: TextStyle(
                    color: themeProvider.isDarkMode
                        ? darkPrimaryColorL
                        : darkPrimaryColorD,
                    fontSize: 12.0,
                    fontStyle: FontStyle.italic),
              ),
              margin: EdgeInsets.only(left: 50.0, top: 5.0, bottom: 5.0),
            ),

            // Time
            // isLastMessageLeft(index)
            //     ? Container(
            //         child: Text(
            //           DateFormat('dd MMM').format(
            //               DateTime.fromMillisecondsSinceEpoch(
            //                   int.parse(document['timestamp']))),
            //           style: TextStyle(
            //               color: darkPrimaryColor,
            //               fontSize: 12.0,
            //               fontStyle: FontStyle.italic),
            //         ),
            //         margin: EdgeInsets.only(left: 50.0, top: 5.0, bottom: 5.0),
            //       )
            //     : Container()
          ],
          crossAxisAlignment: CrossAxisAlignment.start,
        ),
        margin: EdgeInsets.only(bottom: 10.0),
      );
    }
  }

  bool isLastMessageLeft(int index) {
    if ((index > 0 &&
            listMessage != null &&
            listMessage[index - 1]['idFrom'] == id) ||
        index == 0) {
      return true;
    } else {
      return false;
    }
  }

  bool isLastMessageRight(int index) {
    if ((index > 0 &&
            listMessage != null &&
            listMessage[index - 1]['idFrom'] != id) ||
        index == 0) {
      return true;
    } else {
      return false;
    }
  }

  Future<bool> onBackPress() {
    if (isShowSticker) {
      setState(() {
        isShowSticker = false;
      });
    } else {
      Firestore.instance
          .collection('users')
          .document(id)
          .updateData({'chattingWith': null, 'online': false});
      Navigator.pop(context);
    }

    return Future.value(false);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      child: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              // List of messages
              buildListMessage(),

              // Sticker
              (isShowSticker ? buildSticker() : Container()),

              // Input content
              buildInput(),
            ],
          ),

          // Loading
          buildLoading()
        ],
      ),
      onWillPop: onBackPress,
    );
  }

  Widget buildSticker() {
    final themeProvider = Provider.of<DynamicTheme>(context);
    return Container(
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  Material(
                    child: new Container(
                      width: 60,
                      height: 40,
                      margin: new EdgeInsets.symmetric(horizontal: 1.0),
                      child: new FlatButton(
                        onPressed: getGIF,
                        color: themeProvider.isDarkMode
                            ? rightTextColorL
                            : rightTextColorD,
                        child: themeProvider.isDarkMode
                            ? Image.asset('assets/images/gif2.jpg')
                            : Image.asset(
                                'assets/images/gif.jpg',
                                // width: 40,
                                // fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    color: themeProvider.isDarkMode
                        ? rightTextColorL
                        : rightTextColorD,
                  ),
                ],
              ),
              Flexible(
                child: Text('Add GIF, photos and more...',
                    style: TextStyle(
                        color: themeProvider.isDarkMode
                            ? primaryColorL
                            : primaryColorD)),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  Material(
                    child: new Container(
                      margin: new EdgeInsets.symmetric(horizontal: 1.0),
                      child: new IconButton(
                        icon: new Icon(Icons.camera_alt),
                        onPressed: getImageCamera,
                        color: themeProvider.isDarkMode
                            ? primaryColorL
                            : primaryColorD,
                      ),
                    ),
                    color: themeProvider.isDarkMode
                        ? rightTextColorL
                        : rightTextColorD,
                  ),
                  Material(
                    child: new Container(
                      margin: new EdgeInsets.symmetric(horizontal: 1.0),
                      child: new IconButton(
                        icon: new Icon(Icons.image),
                        onPressed: getImage,
                        color: themeProvider.isDarkMode
                            ? primaryColorL
                            : primaryColorD,
                      ),
                    ),
                    color: themeProvider.isDarkMode
                        ? rightTextColorL
                        : rightTextColorD,
                  ),
                ],
              ),
            ],
          ),
          Container(
            color: themeProvider.isDarkMode
                ? lightPrimaryColorL
                : lightPrimaryColorD,
            height: 181,
            child: Scrollbar(
              child: GridView.count(
                crossAxisCount: 3,
                children: <Widget>[
                  FlatButton(
                    onPressed: () => onSendMessage('mimi1', 2),
                    child: new Image.asset(
                      'assets/images/mimi1.gif',
                      width: 50.0,
                      height: 50.0,
                      fit: BoxFit.cover,
                    ),
                  ),
                  FlatButton(
                    onPressed: () => onSendMessage('mimi2', 2),
                    child: new Image.asset(
                      'assets/images/mimi2.gif',
                      width: 50.0,
                      height: 50.0,
                      fit: BoxFit.cover,
                    ),
                  ),
                  FlatButton(
                    onPressed: () => onSendMessage('mimi3', 2),
                    child: new Image.asset(
                      'assets/images/mimi3.gif',
                      width: 50.0,
                      height: 50.0,
                      fit: BoxFit.cover,
                    ),
                  ),
                  FlatButton(
                    onPressed: () => onSendMessage('mimi4', 2),
                    child: new Image.asset(
                      'assets/images/mimi4.gif',
                      width: 50.0,
                      height: 50.0,
                      fit: BoxFit.cover,
                    ),
                  ),
                  FlatButton(
                    onPressed: () => onSendMessage('mimi5', 2),
                    child: new Image.asset(
                      'assets/images/mimi5.gif',
                      width: 50.0,
                      height: 50.0,
                      fit: BoxFit.cover,
                    ),
                  ),
                  FlatButton(
                    onPressed: () => onSendMessage('mimi6', 2),
                    child: new Image.asset(
                      'assets/images/mimi6.gif',
                      width: 50.0,
                      height: 50.0,
                      fit: BoxFit.cover,
                    ),
                  ),
                  FlatButton(
                    onPressed: () => onSendMessage('mimi7', 2),
                    child: new Image.asset(
                      'assets/images/mimi7.gif',
                      width: 50.0,
                      height: 50.0,
                      fit: BoxFit.cover,
                    ),
                  ),
                  FlatButton(
                    onPressed: () => onSendMessage('mimi8', 2),
                    child: new Image.asset(
                      'assets/images/mimi8.gif',
                      width: 50.0,
                      height: 50.0,
                      fit: BoxFit.cover,
                    ),
                  ),
                  FlatButton(
                    onPressed: () => onSendMessage('mimi9', 2),
                    child: new Image.asset(
                      'assets/images/mimi9.gif',
                      width: 50.0,
                      height: 50.0,
                      fit: BoxFit.cover,
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
        // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      ),
      decoration: new BoxDecoration(
          border: new Border(
              top: new BorderSide(
                  color: themeProvider.isDarkMode
                      ? lightPrimaryColorL
                      : lightPrimaryColorD,
                  width: 0.5)),
          color: themeProvider.isDarkMode ? rightTextColorL : rightTextColorD),
      padding: EdgeInsets.all(5.0),
      height: 240.0,
    );
  }

  Widget buildLoading() {
    final themeProvider = Provider.of<DynamicTheme>(context);
    return Positioned(
      child: isLoading
          ? Container(
              child: Center(
                child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                        themeProvider.isDarkMode
                            ? darkPrimaryColorL
                            : darkPrimaryColorD)),
              ),
              color: Colors.white.withOpacity(0.8),
            )
          : Container(),
    );
  }

  Widget buildInput() {
    final themeProvider = Provider.of<DynamicTheme>(context);
    return Container(
      child: Row(
        children: <Widget>[
          // Button send image

          Material(
            child: new Container(
              margin: new EdgeInsets.symmetric(horizontal: 1.0),
              child: new IconButton(
                icon: new Icon(FontAwesomeIcons.paperclip),
                onPressed: getSticker,
                color: themeProvider.isDarkMode ? primaryColorL : primaryColorD,
              ),
            ),
            color: themeProvider.isDarkMode ? rightTextColorL : rightTextColorD,
          ),

          // Edit text
          Flexible(
            child: Container(
              child: TextField(
                style: TextStyle(
                    color: themeProvider.isDarkMode
                        ? primaryColorL
                        : primaryColorD,
                    fontSize: 15.0),
                controller: textEditingController,
                decoration: InputDecoration.collapsed(
                  hintText: 'Type your message...',
                  hintStyle: TextStyle(
                      color: themeProvider.isDarkMode
                          ? darkPrimaryColorL
                          : darkPrimaryColorD),
                ),
                focusNode: focusNode,
              ),
            ),
          ),

          // Button send message
          Material(
            child: new Container(
              margin: new EdgeInsets.only(left: 8.0, right: 8.0),
              child: new IconButton(
                icon: new Icon(Icons.send),
                onPressed: () => onSendMessage(textEditingController.text, 0),
                color: themeProvider.isDarkMode
                    ? darkPrimaryColorL
                    : darkPrimaryColorD,
              ),
            ),
            color: themeProvider.isDarkMode ? rightTextColorL : rightTextColorD,
          ),
        ],
      ),
      width: double.infinity,
      height: 50.0,
      decoration: new BoxDecoration(
          border: new Border(
              top: new BorderSide(
                  color: themeProvider.isDarkMode
                      ? lightPrimaryColorL
                      : lightPrimaryColorD,
                  width: 0.5)),
          color: themeProvider.isDarkMode ? rightTextColorL : rightTextColorD),
    );
  }

  Widget buildListMessage() {
    final themeProvider = Provider.of<DynamicTheme>(context);
    return Flexible(
      child: groupChatId == ''
          ? Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                      themeProvider.isDarkMode
                          ? darkPrimaryColorL
                          : darkPrimaryColorD)))
          : StreamBuilder(
              stream: Firestore.instance
                  .collection('messages')
                  .document(groupChatId)
                  .collection(groupChatId)
                  .orderBy('timestamp', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                      child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              themeProvider.isDarkMode
                                  ? darkPrimaryColorL
                                  : darkPrimaryColorD)));
                } else {
                  listMessage = snapshot.data.documents;
                  return ListView.builder(
                    padding: EdgeInsets.all(10.0),
                    itemBuilder: (context, index) =>
                        buildItem(index, snapshot.data.documents[index]),
                    itemCount: snapshot.data.documents.length,
                    reverse: true,
                    controller: listScrollController,
                  );
                }
              },
            ),
    );
  }
}
