
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/constants.dart';

abstract class AssetPickerViewerBuilderDelegate<A, P> {
  AssetPickerViewerBuilderDelegate({
    @required this.provider,
    @required this.previewAssets,
    @required this.themeData,
    @required int currentIndex,
    this.selectedAssets,
    this.selectorProvider,
  }) {
    _currentIndex = currentIndex;
  }

  /// [ChangeNotifier] for photo selector viewer.
  final AssetPickerViewerProvider<A> provider;

  /// Assets provided to preview.
  final List<A> previewAssets;

  /// Theme for the viewer.
  final ThemeData themeData;

  /// Selected assets.
  final List<A> selectedAssets;

  /// Provider for [AssetPicker].
  final AssetPickerProvider<A, P> selectorProvider;

  /// [StreamController] for viewing page index update.
  ///
  /// The main purpose is narrow down build parts when page index is changing,
  /// prevent widely [setState] and causing other widgets rebuild.
  final StreamController<int> pageStreamController =
      StreamController<int>.broadcast();

  AssetPickerViewerState<A, P> viewerState;

  /// The [TickerProvider] for animations.
  TickerProvider vsync;

  /// Current previewing index in assets.
  int _currentIndex;

  int get currentIndex => _currentIndex;

  set currentIndex(int value) {
    if (_currentIndex == value) {
      return;
    }
    _currentIndex = value;
  }

  /// Getter for the current asset.
  A get currentAsset => previewAssets.elementAt(currentIndex);

  /// Height for bottom detail widget.
  double get bottomDetailHeight => 140.0;

  /// Whether the current platform is Apple OS.
  bool get isAppleOS => Platform.isIOS || Platform.isMacOS;

  /// Call when viewer is calling [initState].
  void initStateAndTicker(AssetPickerViewerState<A, P> s, TickerProvider v) {
    viewerState = s;
    vsync = v;
  }

  /// Keep a dispose method to sync with [State].
  void dispose();

  /// Split page builder according to type of asset.
  Widget assetPageBuilder(BuildContext context, int index);

  /// Common image load state changed callback with [Widget].
  Widget previewWidgetLoadStateChanged(
    BuildContext context,
    ExtendedImageState state,
  ) {
    Widget loader;
    switch (state.extendedImageLoadState) {
      case LoadState.loading:
        loader = const SizedBox.shrink();
        break;
      case LoadState.completed:
        loader = FadeImageBuilder(child: state.completedWidget);
        break;
      case LoadState.failed:
        loader = failedItemBuilder(context);
        break;
    }
    return loader;
  }

  /// The item widget when [AssetEntity.thumbData] load failed.
  Widget failedItemBuilder(BuildContext context) {
    return Center(
      child: Text(
        Constants.textDelegate.loadFailed,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 18.0),
      ),
    );
  }

  /// Confirm button.
  Widget confirmButton(BuildContext context);

  /// Select button.
  Widget selectButton(BuildContext context);

  /// Thumb item widgets in bottom detail.
  Widget bottomDetailItemBuilder(BuildContext context, int index);

  /// Detail widget aligned to bottom.
  Widget bottomDetailBuilder(BuildContext context);

  /// Yes, the build method.
  Widget build(BuildContext context);
}

class DefaultAssetPickerViewerBuilderDelegate
    extends AssetPickerViewerBuilderDelegate<AssetEntity, AssetPathEntity> {
  DefaultAssetPickerViewerBuilderDelegate({
    @required int currentIndex,
    @required List<AssetEntity> previewAssets,
    @required AssetPickerViewerProvider<AssetEntity> provider,
    @required ThemeData themeData,
    List<AssetEntity> selectedAssets,
    AssetPickerProvider<AssetEntity, AssetPathEntity> selectorProvider,
    this.previewThumbSize,
    this.specialPickerType,
  }) : super(
          currentIndex: currentIndex,
          previewAssets: previewAssets,
          provider: provider,
          themeData: themeData,
          selectedAssets: selectedAssets,
          selectorProvider: selectorProvider,
        );

  /// Thumb size for the preview of images in the viewer.
  final List<int> previewThumbSize;

  /// The current special picker type for the viewer.
  ///
  /// If the type is not null, the title of the viewer will not display.
  final SpecialPickerType specialPickerType;

  /// [AnimationController] for double tap animation.
  AnimationController _doubleTapAnimationController;

  /// [CurvedAnimation] for double tap.
  Animation<double> _doubleTapCurveAnimation;

  /// [Animation] for double tap.
  Animation<double> _doubleTapAnimation;

  /// Callback for double tap.
  VoidCallback _doubleTapListener;

  /// [PageController] for assets preview [PageView].
  PageController pageController;

  /// Whether detail widgets displayed.
  bool isDisplayingDetail = true;

  @override
  void initStateAndTicker(
    AssetPickerViewerState<AssetEntity, AssetPathEntity> s,
    TickerProvider v,
  ) {
    super.initStateAndTicker(s, v);
    _doubleTapAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: v,
    );
    _doubleTapCurveAnimation = CurvedAnimation(
      parent: _doubleTapAnimationController,
      curve: Curves.easeInOut,
    );
    pageController = PageController(initialPage: currentIndex);
  }

  @override
  void dispose() {
    _doubleTapAnimationController?.dispose();
    pageStreamController?.close();
  }

  /// Execute scale animation when double tap.
  void updateAnimation(ExtendedImageGestureState state) {
    final double begin = state.gestureDetails.totalScale;
    final double end = state.gestureDetails.totalScale == 1.0 ? 3.0 : 1.0;
    final Offset pointerDownPosition = state.pointerDownPosition;

    _doubleTapAnimation?.removeListener(_doubleTapListener);
    _doubleTapAnimationController
      ..stop()
      ..reset();
    _doubleTapListener = () {
      state.handleDoubleTap(
        scale: _doubleTapAnimation.value,
        doubleTapPosition: pointerDownPosition,
      );
    };
    _doubleTapAnimation = Tween<double>(
      begin: begin,
      end: end,
    ).animate(_doubleTapCurveAnimation)
      ..addListener(_doubleTapListener);

    _doubleTapAnimationController.forward();
  }

  /// Method to switch [isDisplayingDetail].
  void switchDisplayingDetail({bool value}) {
    isDisplayingDetail = value ?? !isDisplayingDetail;
    if (viewerState.mounted) {
      // ignore: invalid_use_of_protected_member
      viewerState.setState(() {});
    }
  }

  /// Sync selected assets currently with asset picker provider.
  Future<bool> syncSelectedAssetsWhenPop() async {
    if (provider?.currentlySelectedAssets != null) {
      selectorProvider.selectedAssets = provider.currentlySelectedAssets;
    }
    return true;
  }

  @override
  Widget assetPageBuilder(BuildContext context, int index) {
    final AssetEntity asset = previewAssets.elementAt(index);
    Widget builder;
    switch (asset.type) {
      case AssetType.audio:
        builder = AudioPageBuilder(asset: asset, state: viewerState);
        break;
      case AssetType.image:
        builder = ImagePageBuilder(
          asset: asset,
          state: viewerState,
          previewThumbSize: previewThumbSize,
        );
        break;
      case AssetType.video:
        builder = VideoPageBuilder(asset: asset, state: viewerState);
        break;
      case AssetType.other:
        builder = Center(
          child: Text(Constants.textDelegate.unSupportedAssetType),
        );
        break;
    }
    return builder;
  }

  /// Preview item widgets for audios.
  Widget _audioPreviewItem(AssetEntity asset) {
    return ColoredBox(
      color: viewerState.context?.themeData?.dividerColor,
      child: const Center(child: Icon(Icons.audiotrack)),
    );
  }

  /// Preview item widgets for images.
  Widget _imagePreviewItem(AssetEntity asset) {
    return Positioned.fill(
      child: RepaintBoundary(
        child: ExtendedImage(
          image: AssetEntityImageProvider(
            asset,
            isOriginal: false,
          ),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  /// Preview item widgets for video.
  Widget _videoPreviewItem(AssetEntity asset) {
    return Positioned.fill(
      child: Stack(
        children: <Widget>[
          _imagePreviewItem(asset),
          Center(
            child: Icon(
              Icons.video_library,
              color: themeData.colorScheme.surface.withOpacity(0.54),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget bottomDetailItemBuilder(BuildContext context, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: StreamBuilder<int>(
          initialData: currentIndex,
          stream: pageStreamController.stream,
          builder: (BuildContext _, AsyncSnapshot<int> snapshot) {
            final AssetEntity asset = selectedAssets.elementAt(index);
            final bool isViewing = asset == currentAsset;
            return GestureDetector(
              onTap: () {
                if (previewAssets == selectedAssets) {
                  pageController.jumpToPage(index);
                }
              },
              child: Selector<AssetPickerViewerProvider<AssetEntity>,
                  List<AssetEntity>>(
                selector: (
                  BuildContext _,
                  AssetPickerViewerProvider<AssetEntity> provider,
                ) =>
                    provider.currentlySelectedAssets,
                builder: (
                  BuildContext _,
                  List<AssetEntity> currentlySelectedAssets,
                  Widget __,
                ) {
                  final bool isSelected =
                      currentlySelectedAssets.contains(asset);
                  return Stack(
                    children: <Widget>[
                      () {
                        Widget item;
                        switch (asset.type) {
                          case AssetType.other:
                            item = const SizedBox.shrink();
                            break;
                          case AssetType.image:
                            item = _imagePreviewItem(asset);
                            break;
                          case AssetType.video:
                            item = _videoPreviewItem(asset);
                            break;
                          case AssetType.audio:
                            item = _audioPreviewItem(asset);
                            break;
                        }
                        return item;
                      }(),
                      AnimatedContainer(
                        duration: kThemeAnimationDuration,
                        curve: Curves.easeInOut,
                        decoration: BoxDecoration(
                          border: isViewing
                              ? Border.all(
                                  color: themeData.colorScheme.secondary,
                                  width: 2.0,
                                )
                              : null,
                          color: isSelected
                              ? null
                              : themeData.colorScheme.surface.withOpacity(0.54),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget bottomDetailBuilder(BuildContext context) {
    return AnimatedPositioned(
      duration: kThemeAnimationDuration,
      curve: Curves.easeInOut,
      bottom: isDisplayingDetail
          ? 0.0
          : -(Screens.bottomSafeHeight + bottomDetailHeight),
      left: 0.0,
      right: 0.0,
      height: Screens.bottomSafeHeight + bottomDetailHeight,
      child: Container(
        padding: EdgeInsets.only(bottom: Screens.bottomSafeHeight),
        color: themeData.canvasColor.withOpacity(0.85),
        child: Column(
          children: <Widget>[
            ChangeNotifierProvider<
                AssetPickerViewerProvider<AssetEntity>>.value(
              value: provider,
              child: SizedBox(
                height: 90.0,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 5.0),
                  itemCount: selectedAssets.length,
                  itemBuilder: bottomDetailItemBuilder,
                ),
              ),
            ),
            Container(
              height: 1.0,
              color: themeData.dividerColor,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Spacer(),
                    if (isAppleOS && provider != null)
                      ChangeNotifierProvider<
                          AssetPickerViewerProvider<AssetEntity>>.value(
                        value: provider,
                        child: confirmButton(context),
                      )
                    else
                      selectButton(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// AppBar widget.
  Widget appBar(BuildContext context) {
    return AnimatedPositioned(
      duration: kThemeAnimationDuration,
      curve: Curves.easeInOut,
      top: isDisplayingDetail ? 0.0 : -(Screens.topSafeHeight + kToolbarHeight),
      left: 0.0,
      right: 0.0,
      height: Screens.topSafeHeight + kToolbarHeight,
      child: Container(
        padding: EdgeInsets.only(top: Screens.topSafeHeight, right: 12.0),
        color: themeData.canvasColor.withOpacity(0.85),
        child: Row(
          children: <Widget>[
            const BackButton(),
            if (!isAppleOS && specialPickerType == null)
              StreamBuilder<int>(
                initialData: currentIndex,
                stream: pageStreamController.stream,
                builder: (BuildContext _, AsyncSnapshot<int> snapshot) {
                  return Text(
                    '${snapshot.data + 1}/${previewAssets.length}',
                    style: const TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            const Spacer(),
            if (isAppleOS && provider != null) selectButton(context),
            if (!isAppleOS && provider != null ||
                specialPickerType == SpecialPickerType.wechatMoment)
              confirmButton(context),
          ],
        ),
      ),
    );
  }

  /// It'll pop with [AssetPickerProvider.selectedAssets] when there're any
  /// assets chosen. The [PhotoSelector] will recognize and pop too.
  @override
  Widget confirmButton(BuildContext context) {
    return ChangeNotifierProvider<AssetPickerViewerProvider<AssetEntity>>.value(
      value: provider,
      child: Consumer<AssetPickerViewerProvider<AssetEntity>>(
        builder: (
          BuildContext _,
          AssetPickerViewerProvider<AssetEntity> provider,
          Widget __,
        ) {
          return MaterialButton(
            minWidth: () {
              if (specialPickerType == SpecialPickerType.wechatMoment) {
                return 48.0;
              }
              return provider.isSelectedNotEmpty ? 48.0 : 20.0;
            }(),
            height: 32.0,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            color: () {
              if (specialPickerType == SpecialPickerType.wechatMoment) {
                return themeData.colorScheme.secondary;
              }
              return provider.isSelectedNotEmpty
                  ? themeData.colorScheme.secondary
                  : themeData.dividerColor;
            }(),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(3.0),
            ),
            child: Text(
              () {
                if (specialPickerType == SpecialPickerType.wechatMoment) {
                  return Constants.textDelegate.confirm;
                }
                if (provider.isSelectedNotEmpty) {
                  return '${Constants.textDelegate.confirm}'
                      '(${provider.currentlySelectedAssets.length}'
                      '/'
                      '${selectorProvider.maxAssets})';
                }
                return Constants.textDelegate.confirm;
              }(),
              style: TextStyle(
                color: () {
                  if (specialPickerType == SpecialPickerType.wechatMoment) {
                    return themeData.textTheme.bodyText1.color;
                  }
                  return provider.isSelectedNotEmpty
                      ? themeData.textTheme.bodyText1.color
                      : themeData.textTheme.caption.color;
                }(),
                fontSize: 17.0,
                fontWeight: FontWeight.normal,
              ),
            ),
            onPressed: () {
              if (specialPickerType == SpecialPickerType.wechatMoment) {
                Navigator.of(context).pop(<AssetEntity>[currentAsset]);
                return;
              }
              if (provider.isSelectedNotEmpty) {
                Navigator.of(context).pop(provider.currentlySelectedAssets);
              }
            },
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        },
      ),
    );
  }

  /// Select button for apple OS.
  Widget _appleOSSelectButton(bool isSelected, AssetEntity asset) {
    return Padding(
      padding: const EdgeInsets.only(right: 10.0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (isSelected) {
            provider.unSelectAssetEntity(asset);
          } else {
            provider.selectAssetEntity(asset);
          }
        },
        child: AnimatedContainer(
          duration: kThemeAnimationDuration,
          width: 28.0,
          decoration: BoxDecoration(
            border: !isSelected
                ? Border.all(
                    color: themeData.iconTheme.color,
                  )
                : null,
            color: isSelected ? themeData.buttonColor : null,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isSelected
                ? Text(
                    (currentIndex + 1).toString(),
                    style: const TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : const Icon(Icons.check, size: 20.0),
          ),
        ),
      ),
    );
  }

  /// Select button for Android.
  Widget _androidSelectButton(bool isSelected, AssetEntity asset) {
    return RoundedCheckbox(
      value: isSelected,
      onChanged: (bool value) {
        if (isSelected) {
          provider.unSelectAssetEntity(asset);
        } else {
          provider.selectAssetEntity(asset);
        }
      },
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  @override
  Widget selectButton(BuildContext context) {
    return Row(
      children: <Widget>[
        StreamBuilder<int>(
          initialData: currentIndex,
          stream: pageStreamController.stream,
          builder: (BuildContext _, AsyncSnapshot<int> snapshot) {
            return ChangeNotifierProvider<
                AssetPickerViewerProvider<AssetEntity>>.value(
              value: provider,
              child: Selector<AssetPickerViewerProvider<AssetEntity>,
                  List<AssetEntity>>(
                selector: (
                  BuildContext _,
                  AssetPickerViewerProvider<AssetEntity> provider,
                ) =>
                    provider.currentlySelectedAssets,
                builder: (
                  BuildContext _,
                  List<AssetEntity> currentlySelectedAssets,
                  Widget __,
                ) {
                  final AssetEntity asset =
                      previewAssets.elementAt(snapshot.data);
                  final bool isSelected =
                      currentlySelectedAssets.contains(asset);
                  if (isAppleOS) {
                    return _appleOSSelectButton(isSelected, asset);
                  } else {
                    return _androidSelectButton(isSelected, asset);
                  }
                },
              ),
            );
          },
        ),
        if (!isAppleOS)
          Text(
            Constants.textDelegate.select,
            style: const TextStyle(fontSize: 18.0),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: syncSelectedAssetsWhenPop,
      child: Theme(
        data: themeData,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: themeData.brightness.isDark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          child: Material(
            color: Colors.black,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: ExtendedImageGesturePageView.builder(
                    physics: const CustomScrollPhysics(),
                    controller: pageController,
                    itemCount: previewAssets.length,
                    itemBuilder: assetPageBuilder,
                    onPageChanged: (int index) {
                      currentIndex = index;
                      pageStreamController.add(index);
                    },
                    scrollDirection: Axis.horizontal,
                  ),
                ),
                appBar(context),
                if (selectedAssets != null) bottomDetailBuilder(context),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
