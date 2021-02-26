import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/constants.dart';

/// The delegate to build the whole picker's components.
///
/// By extending the delegate, you can customize every components on you own.
/// Delegate requires two generic types:
///  * [A] "Asset": The type of your assets. Defaults to [AssetEntity].
///  * [P] "Path": The type of your paths. Defaults to [AssetPathEntity].
abstract class AssetPickerBuilderDelegate<A, P> {
  AssetPickerBuilderDelegate({
    @required this.provider,
    int gridCount = 4,
    Color themeColor,
    this.userName,
    AssetsPickerTextDelegate textDelegate,
    this.pickerTheme,
    this.specialItemPosition = SpecialItemPosition.none,
    this.specialItemBuilder,
    this.allowSpecialItemWhenEmpty = false,
  })  : assert(
          pickerTheme == null || themeColor == null,
          'Theme and theme color cannot be set at the same time.',
        ),
        gridCount = gridCount ?? 4,
        themeColor = pickerTheme?.colorScheme?.secondary ?? themeColor ?? C.themeColor {
    Constants.textDelegate = textDelegate ?? DefaultAssetsPickerTextDelegate();
  }

  /// [ChangeNotifier] for asset picker.
  final AssetPickerProvider<A, P> provider;

  /// Assets count for the picker.
  final int gridCount;

  /// Main color for the picker.
  final Color themeColor;

  /// Theme for the picker.
  ///
  /// Usually the WeChat uses the dark version (dark background color)
  /// for the picker. However, some others want a light or a custom version.
  ///
  final ThemeData pickerTheme;

  /// Allow users set a special item in the picker with several positions.
  final SpecialItemPosition specialItemPosition;

  /// The widget builder for the the special item.
  final WidgetBuilder specialItemBuilder;

  /// Whether the special item will display or not when assets is empty.
  final bool allowSpecialItemWhenEmpty;

  /// [ThemeData] for the picker.
  ThemeData get theme => pickerTheme ?? AssetPicker.themeData(themeColor);

  /// Return a system ui overlay style according to
  /// the brightness of the theme data.
  SystemUiOverlayStyle get overlayStyle => theme.brightness == Brightness.light ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light;

  /// Whether the current platform is Apple OS.
  bool get isAppleOS => Platform.isIOS || Platform.isMacOS;

  /// Whether the picker is under the single asset mode.
  bool get isSingleAssetMode => provider.maxAssets == 1;

  /// Space between assets item widget.
  double get itemSpacing => 2.0;

  /// Item's height in app bar.
  double get appBarItemHeight => 32.0;

  /// Blur radius in Apple OS layout mode.
  double get appleOSBlurRadius => 15.0;

  /// Height for bottom action bar.
  double get bottomActionBarHeight => kToolbarHeight / 1.1;

  /// Path entity select widget builder.
  Widget pathEntitySelector(BuildContext context);

  /// Item widgets for path entity selector.
  Widget pathEntityWidget(BuildContext context, P path);

  /// A backdrop widget behind the [pathEntityListWidget].
  ///
  /// While the picker is switching path, this will displayed.
  /// If the user tapped on it, it'll collapse the list widget.
  ///
  Widget pathEntityListBackdrop(BuildContext context);

  /// List widget for path entities.
  Widget pathEntityListWidget(BuildContext context);

  /// Confirm button.
  Widget confirmButton(BuildContext context);

  String userName;

  /// GIF image type indicator.
  Widget gifIndicator(BuildContext context, A asset) {
    return Align(
      alignment: AlignmentDirectional.bottomStart,
      child: Container(
        width: double.maxFinite,
        height: 26.0,
        padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.bottomCenter,
            end: AlignmentDirectional.topCenter,
            colors: <Color>[theme.dividerColor, Colors.transparent],
          ),
        ),
        child: Align(
          alignment: const FractionalOffset(0.1, 0.1),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 2.0,
              vertical: 2.0,
            ),
            decoration: !isAppleOS
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(2.0),
                    color: theme.iconTheme.color.withOpacity(0.75),
                  )
                : null,
            child: Text(
              Constants.textDelegate.gifIndicator,
              style: TextStyle(
                color: isAppleOS ? theme.textTheme.bodyText2.color : theme.primaryColor,
                fontSize: isAppleOS ? 14.0 : 12.0,
                fontWeight: isAppleOS ? FontWeight.w500 : FontWeight.normal,
              ),
              strutStyle: const StrutStyle(
                forceStrutHeight: true,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Audio asset type indicator.
  Widget audioIndicator(BuildContext context, A asset);

  /// Video asset type indicator.
  Widget videoIndicator(BuildContext context, A asset);

  /// Animated backdrop widget for items.
  Widget selectedBackdrop(
    BuildContext context,
    int index,
    A asset,
  );

  /// Indicator for assets selected status.
  Widget selectIndicator(BuildContext context, A asset);

  /// Loading indicator.
  Widget loadingIndicator(BuildContext context);

  /// Indicator when no assets.
  Widget assetsEmptyIndicator(BuildContext context) {
    return Center(
      child: Selector<AssetPickerProvider<A, P>, bool>(
        selector: (BuildContext _, AssetPickerProvider<A, P> provider) => provider.isAssetsEmpty,
        builder: (BuildContext _, bool isAssetsEmpty, Widget __) {
          if (isAssetsEmpty) {
            return Text(Constants.textDelegate.emptyPlaceHolder);
          } else {
            return PlatformProgressIndicator(
              color: theme.iconTheme.color,
              size: Screens.width / gridCount / 3,
            );
          }
        },
      ),
    );
  }

  /// Item widgets when the thumb data load failed.
  Widget failedItemBuilder(BuildContext context) {
    return Center(
      child: Text(
        Constants.textDelegate.loadFailed,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 18.0),
      ),
    );
  }

  /// The main grid view builder for assets.
  Widget assetsGridBuilder(BuildContext context) {
    return ColoredBox(
      color: theme.canvasColor,
      child: Selector<AssetPickerProvider<A, P>, List<A>>(
        selector: (BuildContext _, AssetPickerProvider<A, P> provider) => provider.currentAssets,
        builder: (
          BuildContext _,
          List<A> currentAssets,
          Widget __,
        ) {
          return GridView.builder(
            padding: isAppleOS
                ? EdgeInsets.only(
                    top: Screens.topSafeHeight + kToolbarHeight,
                    bottom: bottomActionBarHeight,
                  )
                : EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: gridCount,
              mainAxisSpacing: itemSpacing,
              crossAxisSpacing: itemSpacing,
            ),
            itemCount: assetsGridItemCount(_, currentAssets),
            itemBuilder: (BuildContext _, int index) {
              return assetGridItemBuilder(_, index, currentAssets);
            },
          );
        },
      ),
    );
  }

  /// The function which return items count for the assets' grid.
  int assetsGridItemCount(BuildContext context, List<A> currentAssets);

  /// The item builder for the assets' grid.
  Widget assetGridItemBuilder(
    BuildContext context,
    int index,
    List<A> currentAssets,
  );

  /// The item builder for audio type of asset.
  Widget audioItemBuilder(
    BuildContext context,
    int index,
    A asset,
  );

  /// The item builder for images and video type of asset.
  Widget imageAndVideoItemBuilder(
    BuildContext context,
    int index,
    A asset,
  );

  /// Preview button to preview selected assets.
  Widget previewButton(BuildContext context);

  /// Action bar widget aligned to bottom.
  Widget bottomActionBar(BuildContext context) {
    Widget child = Container(
      width: Screens.width,
      height: bottomActionBarHeight + Screens.bottomSafeHeight,
      padding: EdgeInsets.only(
        left: 20.0,
        right: 20.0,
        bottom: Screens.bottomSafeHeight,
      ),
      color: theme.primaryColor.withOpacity(isAppleOS ? 0.90 : 1.0),
      child: Row(children: <Widget>[
        if (!isSingleAssetMode || !isAppleOS) previewButton(context),
        if (isAppleOS) const Spacer(),
        if (isAppleOS) confirmButton(context),
      ]),
    );
    if (isAppleOS) {
      child = ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: appleOSBlurRadius,
            sigmaY: appleOSBlurRadius,
          ),
          child: child,
        ),
      );
    }
    return child;
  }

  /// Back button.
  Widget backButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: () {
        if (isAppleOS) {
          return GestureDetector(
            onTap: Navigator.of(context).maybePop,
            child: Container(
              margin: isAppleOS ? const EdgeInsets.symmetric(horizontal: 20.0) : null,
              child: IntrinsicWidth(
                child: Center(
                  child: Text(
                    Constants.textDelegate.cancel,
                    style: const TextStyle(fontSize: 18.0),
                  ),
                ),
              ),
            ),
          );
        } else {
          return IconButton(
            onPressed: Navigator.of(context).maybePop,
            icon: const Icon(Icons.arrow_back_rounded),
          );
        }
      }(),
    );
  }

  /// Custom app bar for the picker.
  Widget appBar(BuildContext context);

  /// Layout for Apple OS devices.
  Widget appleOSLayout(BuildContext context);

  /// Layout for Android devices.
  Widget androidLayout(BuildContext context);

  /// Yes, the build method.
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Theme(
        data: theme,
        child: ChangeNotifierProvider<AssetPickerProvider<A, P>>.value(
          value: provider,
          child: Material(
            color: theme.canvasColor,
            child: isAppleOS ? appleOSLayout(context) : androidLayout(context),
          ),
        ),
      ),
    );
  }
}

class DefaultAssetPickerBuilderDelegate extends AssetPickerBuilderDelegate<AssetEntity, AssetPathEntity> {
  DefaultAssetPickerBuilderDelegate({
    @required DefaultAssetPickerProvider provider,
    int gridCount = 4,
    String userName,
    Color themeColor,
    AssetsPickerTextDelegate textDelegate,
    ThemeData pickerTheme,
    SpecialItemPosition specialItemPosition = SpecialItemPosition.none,
    WidgetBuilder specialItemBuilder,
    bool allowSpecialItemWhenEmpty = false,
    this.previewThumbSize,
    this.specialPickerType,
  })  : assert(
          provider != null,
          'AssetPickerProvider must be provided and not null.',
        ),
        assert(
          pickerTheme == null || themeColor == null,
          'Theme and theme color cannot be set at the same time.',
        ),
        super(
          provider: provider,
          gridCount: gridCount,
          userName: userName,
          themeColor: themeColor,
          textDelegate: textDelegate,
          pickerTheme: pickerTheme,
          specialItemPosition: specialItemPosition,
          specialItemBuilder: specialItemBuilder,
          allowSpecialItemWhenEmpty: allowSpecialItemWhenEmpty,
        );

  /// Thumb size for the preview of images in the viewer.
  ///
  /// This only works on images since other types does not have request
  /// for thumb data. The speed of preview can be raised by reducing it.
  ///
  /// Default is `null`, which will request the origin data.
  final List<int> previewThumbSize;

  /// The current special picker type for the picker.
  ///
  /// There're several types which are special:
  /// * [SpecialPickerType.wechatMoment] When user selected video, no more images
  /// can be selected.
  ///
  final SpecialPickerType specialPickerType;

  /// [Duration] when triggering path switching.
  Duration get switchingPathDuration => kThemeAnimationDuration * 1.5;

  /// [Curve] when triggering path switching.
  Curve get switchingPathCurve => Curves.easeInOut;

  @override
  Widget androidLayout(BuildContext context) {
    return FixedAppBarWrapper(
      appBar: appBar(context),
      body: Selector<DefaultAssetPickerProvider, bool>(
        selector: (
          BuildContext _,
          DefaultAssetPickerProvider provider,
        ) =>
            provider.hasAssetsToDisplay,
        builder: (
          BuildContext _,
          bool hasAssetsToDisplay,
          Widget __,
        ) {
          final bool shouldDisplayAssets = hasAssetsToDisplay || (allowSpecialItemWhenEmpty && specialItemPosition != SpecialItemPosition.none);
          return AnimatedSwitcher(
            duration: switchingPathDuration,
            child: shouldDisplayAssets
                ? Stack(
                    children: <Widget>[
                      RepaintBoundary(
                        child: Column(
                          children: <Widget>[
                            Expanded(child: assetsGridBuilder(context)),
                            if (!isSingleAssetMode) bottomActionBar(context),
                          ],
                        ),
                      ),
                      pathEntityListBackdrop(context),
                      pathEntityListWidget(context),
                      if (!isAppleOS) Positioned.fill(bottom: 20, right: 20, child: Align(alignment: Alignment.bottomRight, child: confirmButton(context))),
                    ],
                  )
                : loadingIndicator(context),
          );
        },
      ),
    );
  }

  @override
  FixedAppBar appBar(BuildContext context) {
    return FixedAppBar(
      backgroundColor: theme.appBarTheme.color,
      centerTitle: isAppleOS,
      title: Text('Send to \"$userName\"', style: const TextStyle(fontSize: 16)),
      // title: pathEntitySelector(context),
      leading: backButton(context),
      actions: <Widget>[
        pathEntitySelector(context),
      ],
      //!isAppleOS ? <Widget>[confirmButton(context)] : null,
      // actionsPadding: const EdgeInsets.only(right: 14.0),
      blurRadius: isAppleOS ? appleOSBlurRadius : 0.0,
    );
  }

  @override
  Widget appleOSLayout(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: Selector<DefaultAssetPickerProvider, bool>(
            selector: (
              BuildContext _,
              DefaultAssetPickerProvider provider,
            ) =>
                provider.hasAssetsToDisplay,
            builder: (
              BuildContext _,
              bool hasAssetsToDisplay,
              Widget __,
            ) {
              return AnimatedSwitcher(
                duration: switchingPathDuration,
                child: hasAssetsToDisplay
                    ? Stack(
                        children: <Widget>[
                          RepaintBoundary(
                            child: Stack(
                              children: <Widget>[
                                Positioned.fill(child: assetsGridBuilder(context)),
                                if (!isSingleAssetMode || isAppleOS)
                                  PositionedDirectional(
                                    bottom: 0.0,
                                    child: bottomActionBar(context),
                                  ),
                              ],
                            ),
                          ),
                          pathEntityListBackdrop(context),
                          pathEntityListWidget(context),
                        ],
                      )
                    : assetsEmptyIndicator(context),
              );
            },
          ),
        ),
        appBar(context),
      ],
    );
  }

  /// There're several conditions within this builder:
  ///  * Return [specialItemBuilder] while the current path is all and
  ///    [specialItemPosition] is not equal to [SpecialItemPosition.none].
  ///  * Return item builder according to the asset's type.
  ///    * [AssetType.audio] -> [audioItemBuilder]
  ///    * [AssetType.image], [AssetType.video] -> [imageAndVideoItemBuilder]
  ///  * Load more assets when the index reached at third line counting
  ///    backwards.
  @override
  Widget assetGridItemBuilder(
    BuildContext context,
    int index,
    List<AssetEntity> currentAssets,
  ) {
    final AssetPathEntity currentPathEntity = Provider.of<DefaultAssetPickerProvider>(
      context,
      listen: false,
    ).currentPathEntity;

    int currentIndex;
    switch (specialItemPosition) {
      case SpecialItemPosition.none:
      case SpecialItemPosition.append:
        currentIndex = index;
        break;
      case SpecialItemPosition.prepend:
        currentIndex = index - 1;
        break;
    }

    // Directly return the special item when it's empty.
    if (currentPathEntity == null && allowSpecialItemWhenEmpty && specialItemPosition != SpecialItemPosition.none) {
      return specialItemBuilder(context);
    }

    if (currentPathEntity.isAll && specialItemPosition != SpecialItemPosition.none && (index == 0 || index == currentAssets.length)) {
      return specialItemBuilder(context);
    }

    if (!currentPathEntity.isAll) {
      currentIndex = index;
    }

    if (index == currentAssets.length - gridCount * 3 && context.read<DefaultAssetPickerProvider>().hasMoreToLoad) {
      provider.loadMoreAssets();
    }

    final AssetEntity asset = currentAssets.elementAt(currentIndex);
    Widget builder;
    switch (asset.type) {
      case AssetType.audio:
        builder = audioItemBuilder(context, currentIndex, asset);
        break;
      case AssetType.image:
      case AssetType.video:
        builder = imageAndVideoItemBuilder(context, currentIndex, asset);
        break;
      case AssetType.other:
        builder = const SizedBox.shrink();
        break;
    }
    return Stack(
      children: <Widget>[
        builder,
        if (specialPickerType != SpecialPickerType.wechatMoment || asset.type != AssetType.video) selectIndicator(context, asset),
      ],
    );
  }

  @override
  int assetsGridItemCount(
    BuildContext context,
    List<AssetEntity> currentAssets,
  ) {
    final AssetPathEntity currentPathEntity = Provider.of<DefaultAssetPickerProvider>(
      context,
      listen: false,
    ).currentPathEntity;

    if (currentPathEntity == null && specialItemPosition != SpecialItemPosition.none) {
      return 1;
    }

    /// Return actual length if current path is all.
    if (!currentPathEntity.isAll) {
      return currentAssets.length;
    }
    int length;
    switch (specialItemPosition) {
      case SpecialItemPosition.none:
        length = currentAssets.length;
        break;
      case SpecialItemPosition.prepend:
      case SpecialItemPosition.append:
        length = currentAssets.length + 1;
        break;
    }
    return length;
  }

  @override
  Widget audioIndicator(BuildContext context, AssetEntity asset) {
    return Align(
      alignment: AlignmentDirectional.bottomStart,
      child: Container(
        width: double.maxFinite,
        padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 8.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.bottomCenter,
            end: AlignmentDirectional.topCenter,
            colors: <Color>[theme.dividerColor, Colors.transparent],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 4.0),
          child: Text(
            Constants.textDelegate.durationIndicatorBuilder(Duration(seconds: asset.duration)),
            style: const TextStyle(fontSize: 16.0),
          ),
        ),
      ),
    );
  }

  @override
  Widget audioItemBuilder(BuildContext context, int index, AssetEntity asset) {
    return Stack(
      children: <Widget>[
        Align(
          alignment: AlignmentDirectional.topStart,
          child: Container(
            width: double.maxFinite,
            padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 8.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.topCenter,
                end: AlignmentDirectional.bottomCenter,
                colors: <Color>[theme.dividerColor, Colors.transparent],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 4.0, right: 30.0),
              child: Text(
                asset.title,
                style: const TextStyle(fontSize: 16.0),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        const Center(child: Icon(Icons.audiotrack)),
        selectedBackdrop(context, index, asset),
        audioIndicator(context, asset),
      ],
    );
  }

  /// It'll pop with [AssetPickerProvider.selectedAssets]
  /// when there're any assets chosen.
  @override
  Widget confirmButton(BuildContext context) {
    return Consumer<DefaultAssetPickerProvider>(
      builder: (
        BuildContext _,
        DefaultAssetPickerProvider provider,
        Widget __,
      ) {
        return GestureDetector(
          onTap: () {
            if (provider.isSelectedNotEmpty) {
              Navigator.of(context).pop(provider.selectedAssets);
            }
          },
          child: Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(color: provider.isSelectedNotEmpty ? themeColor : theme.dividerColor, shape: BoxShape.circle),
            child: const Icon(Icons.send, color: Colors.white),
          ),
        );
        return MaterialButton(
          minWidth: 48,
          // provider.isSelectedNotEmpty ? 48.0 : 20.0,
          height: 48,
          // provider.isSelectedNotEmpty ? 48.0 : 20.0,//appBarItemHeight,
          // padding: const EdgeInsets.symmetric(horizontal: 12.0),
          color: provider.isSelectedNotEmpty ? themeColor : theme.dividerColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(48)),
          child: Icon(Icons.send, color: provider.isSelectedNotEmpty ? theme.textTheme.bodyText1.color : theme.textTheme.caption.color),
          // Text(
          //   provider.isSelectedNotEmpty && !isSingleAssetMode
          //       ? '${Constants.textDelegate.confirm}'
          //           '(${provider.selectedAssets.length}/${provider.maxAssets})'
          //       : Constants.textDelegate.confirm,
          //   style: TextStyle(
          //     color: provider.isSelectedNotEmpty
          //         ? theme.textTheme.bodyText1.color
          //         : theme.textTheme.caption.color,
          //     fontSize: 17.0,
          //     fontWeight: FontWeight.normal,
          //   ),
          // ),
          onPressed: () {
            if (provider.isSelectedNotEmpty) {
              Navigator.of(context).pop(provider.selectedAssets);
            }
          },
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      },
    );
  }

  @override
  Widget imageAndVideoItemBuilder(
    BuildContext context,
    int index,
    AssetEntity asset,
  ) {
    final AssetEntityImageProvider imageProvider = AssetEntityImageProvider(asset, isOriginal: false);
    return RepaintBoundary(
      child: ExtendedImage(
        image: imageProvider,
        fit: BoxFit.cover,
        loadStateChanged: (ExtendedImageState state) {
          Widget loader;
          switch (state.extendedImageLoadState) {
            case LoadState.loading:
              loader = const ColoredBox(color: Color(0x10ffffff));
              break;
            case LoadState.completed:
              SpecialImageType type;
              if (imageProvider.imageFileType == ImageFileType.gif) {
                type = SpecialImageType.gif;
              } else if (imageProvider.imageFileType == ImageFileType.heic) {
                type = SpecialImageType.heic;
              }
              loader = FadeImageBuilder(
                child: () {
                  final AssetEntity asset = provider.currentAssets.elementAt(index);
                  return Selector<DefaultAssetPickerProvider, List<AssetEntity>>(
                    selector: (
                      BuildContext _,
                      DefaultAssetPickerProvider provider,
                    ) =>
                        provider.selectedAssets,
                    builder: (
                      BuildContext _,
                      List<AssetEntity> selectedAssets,
                      Widget __,
                    ) {
                      return Stack(
                        children: <Widget>[
                          Positioned.fill(
                            child: RepaintBoundary(
                              child: state.completedWidget,
                            ),
                          ),
                          selectedBackdrop(context, index, asset),
                          if (type == SpecialImageType.gif) // 如果为GIF则显示标识
                            gifIndicator(context, asset),
                          if (asset.type == AssetType.video) // 如果为视频则显示标识
                            videoIndicator(context, asset),
                        ],
                      );
                    },
                  );
                }(),
              );
              break;
            case LoadState.failed:
              loader = failedItemBuilder(context);
              break;
          }
          return loader;
        },
      ),
    );
  }

  @override
  Widget loadingIndicator(BuildContext context) {
    return Center(
      child: Selector<DefaultAssetPickerProvider, bool>(
        selector: (
          BuildContext _,
          DefaultAssetPickerProvider provider,
        ) =>
            provider.isAssetsEmpty,
        builder: (BuildContext _, bool isAssetsEmpty, Widget __) {
          if (isAssetsEmpty) {
            return Text(Constants.textDelegate.emptyPlaceHolder);
          } else {
            return PlatformProgressIndicator(
              color: theme.iconTheme.color,
              size: Screens.width / gridCount / 3,
            );
          }
        },
      ),
    );
  }

  /// While the picker is switching path, this will displayed.
  /// If the user tapped on it, it'll collapse the list widget.
  ///
  @override
  Widget pathEntityListBackdrop(BuildContext context) {
    return Selector<DefaultAssetPickerProvider, bool>(
      selector: (
        BuildContext _,
        DefaultAssetPickerProvider provider,
      ) =>
          provider.isSwitchingPath,
      builder: (BuildContext context, bool isSwitchingPath, Widget __) {
        return IgnorePointer(
          ignoring: !isSwitchingPath,
          child: GestureDetector(
            onTap: () {
              context.read<DefaultAssetPickerProvider>().isSwitchingPath = false;
            },
            child: AnimatedOpacity(
              duration: switchingPathDuration,
              opacity: isSwitchingPath ? 1.0 : 0.0,
              child: Container(color: Colors.black.withOpacity(0.75)),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget pathEntityListWidget(BuildContext context) {
    final double appBarHeight = kToolbarHeight + Screens.topSafeHeight;
    final double maxHeight = Screens.height * 0.825;
    return Selector<DefaultAssetPickerProvider, bool>(
      selector: (
        BuildContext _,
        DefaultAssetPickerProvider provider,
      ) =>
          provider.isSwitchingPath,
      builder: (BuildContext _, bool isSwitchingPath, Widget __) {
        return AnimatedPositioned(
          duration: switchingPathDuration,
          curve: switchingPathCurve,
          top: isAppleOS
              ? !isSwitchingPath
                  ? -maxHeight
                  : appBarHeight
              : -(!isSwitchingPath ? maxHeight : 1.0),
          child: AnimatedOpacity(
            duration: switchingPathDuration,
            curve: switchingPathCurve,
            opacity: !isAppleOS || isSwitchingPath ? 1.0 : 0.0,
            child: Container(
              width: Screens.width,
              height: maxHeight,
              decoration: BoxDecoration(
                borderRadius: isAppleOS
                    ? const BorderRadius.only(
                        bottomLeft: Radius.circular(10.0),
                        bottomRight: Radius.circular(10.0),
                      )
                    : null,
                color: theme.colorScheme.background,
              ),
              child: Selector<DefaultAssetPickerProvider, Map<AssetPathEntity, Uint8List>>(
                selector: (
                  BuildContext _,
                  DefaultAssetPickerProvider provider,
                ) =>
                    provider.pathEntityList,
                builder: (
                  BuildContext _,
                  Map<AssetPathEntity, Uint8List> pathEntityList,
                  Widget __,
                ) {
                  return ListView.separated(
                    padding: const EdgeInsets.only(top: 1.0),
                    itemCount: pathEntityList.length,
                    itemBuilder: (BuildContext _, int index) {
                      return pathEntityWidget(
                        context,
                        pathEntityList.keys.elementAt(index),
                      );
                    },
                    separatorBuilder: (BuildContext _, int __) => Container(
                      margin: const EdgeInsets.only(left: 60.0),
                      height: 1.0,
                      color: theme.canvasColor,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget pathEntitySelector(BuildContext context) {
    return IconButton(
        icon: const Icon(Icons.menu, color: Colors.white),
        onPressed: () {
          provider.isSwitchingPath = !provider.isSwitchingPath;
        });
    // return UnconstrainedBox(
    //   child: Consumer<DefaultAssetPickerProvider>(
    //     builder: (
    //       BuildContext _,
    //       DefaultAssetPickerProvider provider,
    //       Widget __,
    //     ) {
    //       return GestureDetector(
    //         onTap: () {
    //           provider.isSwitchingPath = !provider.isSwitchingPath;
    //         },
    //         child: Container(
    //           height: appBarItemHeight,
    //           constraints: BoxConstraints(maxWidth: Screens.width * 0.5),
    //           padding: const EdgeInsets.only(left: 12.0, right: 6.0),
    //           decoration: BoxDecoration(
    //             borderRadius: BorderRadius.circular(999),
    //             color: theme.dividerColor,
    //           ),
    //           child: Row(
    //             mainAxisSize: MainAxisSize.min,
    //             children: <Widget>[
    //               if (provider.currentPathEntity != null)
    //                 Flexible(
    //                   child: Text(
    //                     provider.currentPathEntity.name ?? '',
    //                     style: const TextStyle(
    //                       fontSize: 18.0,
    //                       fontWeight: FontWeight.normal,
    //                     ),
    //                     maxLines: 1,
    //                     overflow: TextOverflow.ellipsis,
    //                   ),
    //                 ),
    //               Padding(
    //                 padding: const EdgeInsets.only(left: 5.0),
    //                 child: DecoratedBox(
    //                   decoration: BoxDecoration(
    //                     shape: BoxShape.circle,
    //                     color: theme.iconTheme.color.withOpacity(0.5),
    //                   ),
    //                   child: Transform.rotate(
    //                     angle: provider.isSwitchingPath ? math.pi : 0.0,
    //                     alignment: Alignment.center,
    //                     child: Icon(
    //                       Icons.keyboard_arrow_down,
    //                       size: 20.0,
    //                       color: theme.colorScheme.primary,
    //                     ),
    //                   ),
    //                 ),
    //               ),
    //             ],
    //           ),
    //         ),
    //       );
    //     },
    //   ),
    // );
  }

  @override
  Widget pathEntityWidget(BuildContext context, AssetPathEntity path) {
    Widget builder(
      BuildContext context,
      Map<AssetPathEntity, Uint8List> pathEntityList,
      Widget __,
    ) {
      if (context.watch<DefaultAssetPickerProvider>().requestType == RequestType.audio) {
        return ColoredBox(
          color: theme.colorScheme.primary.withOpacity(0.12),
          child: const Center(child: Icon(Icons.audiotrack)),
        );
      }

      /// The reason that the `thumbData` should be checked at here to see if it
      /// is null is that even the image file is not exist, the `File` can still
      /// returned as it exist, which will cause the thumb bytes return null.
      ///
      final Uint8List thumbData = pathEntityList[path];
      if (thumbData != null) {
        return Image.memory(
          pathEntityList[path],
          fit: BoxFit.cover,
        );
      } else {
        return ColoredBox(
          color: theme.colorScheme.primary.withOpacity(0.12),
        );
      }
    }

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        splashFactory: InkSplash.splashFactory,
        onTap: () => provider.switchPath(path),
        child: SizedBox(
          height: isAppleOS ? 64.0 : 52.0,
          child: Row(
            children: <Widget>[
              RepaintBoundary(
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: Selector<DefaultAssetPickerProvider, Map<AssetPathEntity, Uint8List>>(
                    selector: (
                      BuildContext _,
                      DefaultAssetPickerProvider provider,
                    ) =>
                        provider.pathEntityList,
                    builder: builder,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 15.0, right: 20.0),
                  child: Row(
                    children: <Widget>[
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 10.0),
                          child: Text(
                            path.name ?? '',
                            style: const TextStyle(fontSize: 18.0),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      Text(
                        '(${path.assetCount})',
                        style: TextStyle(
                          color: theme.textTheme.caption.color,
                          fontSize: 18.0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              Selector<DefaultAssetPickerProvider, AssetPathEntity>(
                selector: (
                  BuildContext _,
                  DefaultAssetPickerProvider provider,
                ) =>
                    provider.currentPathEntity,
                builder: (
                  BuildContext _,
                  AssetPathEntity currentPathEntity,
                  Widget __,
                ) {
                  if (currentPathEntity == path) {
                    return AspectRatio(
                      aspectRatio: 1.0,
                      child: Icon(Icons.check, color: themeColor, size: 26.0),
                    );
                  } else {
                    return const SizedBox.shrink();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget previewButton(BuildContext context) {
    return Selector<DefaultAssetPickerProvider, bool>(
      selector: (BuildContext _, DefaultAssetPickerProvider provider) => provider.isSelectedNotEmpty,
      builder: (BuildContext _, bool isSelectedNotEmpty, Widget __) {
        return GestureDetector(
          onTap: isSelectedNotEmpty
              ? () async {
                  final List<AssetEntity> result = await AssetPickerViewer.pushToViewer(
                    context,
                    currentIndex: 0,
                    previewAssets: provider.selectedAssets,
                    previewThumbSize: previewThumbSize,
                    selectedAssets: provider.selectedAssets,
                    selectorProvider: provider as DefaultAssetPickerProvider,
                    themeData: theme,
                  );
                  if (result != null) {
                    Navigator.of(context).pop(result);
                  }
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Selector<DefaultAssetPickerProvider, List<AssetEntity>>(
              selector: (BuildContext _, DefaultAssetPickerProvider provider) => provider.selectedAssets,
              builder: (
                BuildContext _,
                List<AssetEntity> selectedAssets,
                Widget __,
              ) {
                return Text(
                  isSelectedNotEmpty
                      ? '${Constants.textDelegate.preview}'
                          '(${provider.selectedAssets.length})'
                      : Constants.textDelegate.preview,
                  style: TextStyle(
                    color: isSelectedNotEmpty ? null : theme.textTheme.caption.color,
                    fontSize: 18.0,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget selectIndicator(BuildContext context, AssetEntity asset) {
    return Selector<DefaultAssetPickerProvider, List<AssetEntity>>(
      selector: (BuildContext _, DefaultAssetPickerProvider provider) => provider.selectedAssets,
      builder: (BuildContext _, List<AssetEntity> selectedAssets, Widget __) {
        final bool selected = selectedAssets.contains(asset);
        final double indicatorSize = Screens.width / gridCount / 3;
        return Positioned(
          top: 0.0,
          right: 0.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (selected) {
                provider.unSelectAsset(asset);
              } else {
                if (isSingleAssetMode) {
                  provider.selectedAssets.clear();
                }
                provider.selectAsset(asset);
              }
            },
            child: Container(
              margin: EdgeInsets.all(Screens.width / gridCount / (isAppleOS ? 12.0 : 15.0)),
              width: indicatorSize,
              height: indicatorSize,
              alignment: AlignmentDirectional.topEnd,
              child: AnimatedContainer(
                duration: switchingPathDuration,
                width: indicatorSize / (isAppleOS ? 1.25 : 1.5),
                height: indicatorSize / (isAppleOS ? 1.25 : 1.5),
                decoration: BoxDecoration(
                  border: !selected ? Border.all(color: Colors.white, width: 2.0) : null,
                  color: selected ? themeColor : null,
                  shape: BoxShape.circle,
                ),
                child: AnimatedSwitcher(
                  duration: switchingPathDuration,
                  reverseDuration: switchingPathDuration,
                  child: selected
                      ? isSingleAssetMode
                          ? const Icon(Icons.check, size: 18.0)
                          : Text(
                              '${selectedAssets.indexOf(asset) + 1}',
                              style: TextStyle(
                                color: selected ? theme.textTheme.bodyText1.color : null,
                                fontSize: isAppleOS ? 16.0 : 14.0,
                                fontWeight: isAppleOS ? FontWeight.w600 : FontWeight.bold,
                              ),
                            )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget selectedBackdrop(BuildContext context, int index, AssetEntity asset) {
    return Selector<DefaultAssetPickerProvider, List<AssetEntity>>(
     selector: (BuildContext _, DefaultAssetPickerProvider provider) => provider.selectedAssets,
      builder: (BuildContext _, List<AssetEntity> selectedAssets, Widget __) {
        final bool selected = selectedAssets.contains(asset);
        return Positioned.fill(
          child: GestureDetector(
            onTap: () async {
              final List<AssetEntity> result = await AssetPickerViewer.pushToViewer(
                context,
                currentIndex: index,
                previewAssets: provider.currentAssets,
                themeData: theme,
                previewThumbSize: previewThumbSize,
                specialPickerType: asset.type == AssetType.video ? specialPickerType : null,
              );
              if (result != null) {
                Navigator.of(context).pop(result);
              }
            },
            child: AnimatedContainer(
              duration: switchingPathDuration,
              color: selected ? theme.colorScheme.primary.withOpacity(0.45) : Colors.black.withOpacity(0.1),
            ),
          ), // 点击预览同目录下所有资源
        );
      },
    );
  }

  /// Videos often contains various of color in the cover,
  /// so in order to keep the content visible in most cases,
  /// the color of the indicator has been set to [Colors.white].
  ///
  @override
  Widget videoIndicator(BuildContext context, AssetEntity asset) {
    return Align(
      alignment: AlignmentDirectional.bottomStart,
      child: Container(
        width: double.maxFinite,
        height: 26.0,
        padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.bottomCenter,
            end: AlignmentDirectional.topCenter,
            colors: <Color>[theme.dividerColor, Colors.transparent],
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.videocam,
              size: 24.0,
              color: Colors.white,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Text(
                Constants.textDelegate.durationIndicatorBuilder(
                  Duration(seconds: asset.duration),
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16.0,
                ),
                strutStyle: const StrutStyle(
                  forceStrutHeight: true,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
