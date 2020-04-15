import 'package:flutter/material.dart';
import './const.dart';
import 'package:photo_view/photo_view.dart';
import './theme_provider.dart';
import 'package:provider/provider.dart';

class FullPhoto extends StatelessWidget {
  final String url;

  FullPhoto({Key key, @required this.url}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      body: new FullPhotoScreen(url: url),
    );
  }
}

class FullPhotoScreen extends StatefulWidget {
  final String url;

  FullPhotoScreen({Key key, @required this.url}) : super(key: key);

  @override
  State createState() => new FullPhotoScreenState(url: url);
}

class FullPhotoScreenState extends State<FullPhotoScreen> {
  final String url;

  FullPhotoScreenState({Key key, @required this.url});

  @override
  void initState() {
    super.initState();
  }

  // Widget loadingImage(BuildContext context, ImageChunkEvent imageChunkEvent) {
  //   return LinearProgressIndicator(
  //     value: imageChunkEvent == null
  //         ? 0
  //         : imageChunkEvent.cumulativeBytesLoaded /
  //             imageChunkEvent.expectedTotalBytes,
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<DynamicTheme>(context);
    return Container(
        child: Hero(
      tag: "img$url",
      child: PhotoView(
        imageProvider: NetworkImage(url),
        minScale: 0.3,
        // loadingBuilder: loadingImage,
        backgroundDecoration: BoxDecoration(color: themeProvider.isDarkMode?blackWhiteColorL:blackWhiteColorD),
      ),
    ));
  }
}
