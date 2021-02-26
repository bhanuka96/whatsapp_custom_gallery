/// Text delegate that controls text in widgets.
abstract class AssetsPickerTextDelegate {
  /// Confirm string for the confirm button.
  String confirm;

  /// Cancel string for back button.
  String cancel;

  /// Edit string for edit button.
  String edit;

  /// Placeholder when there's nothing can display in the picker.
  String emptyPlaceHolder;

  /// GIF indicator string.
  String gifIndicator;

  /// HEIC failed string.
  String heicNotSupported;

  /// Load failed string for item.
  String loadFailed;

  /// Original string for original selection.
  String original;

  /// Preview string for preview button.
  String preview;

  /// Select string for select button.
  String select;

  /// Un-supported asset type string for assets that belongs to [AssetType.other].
  String unSupportedAssetType;

  /// This is used in video asset item in the picker, in order
  /// to display the duration of the video or audio type of asset.
  String durationIndicatorBuilder(Duration duration);
}

/// Default text delegate implements with Chinese.
class DefaultAssetsPickerTextDelegate implements AssetsPickerTextDelegate {
  factory DefaultAssetsPickerTextDelegate() => _instance;

  DefaultAssetsPickerTextDelegate._internal();

  static final DefaultAssetsPickerTextDelegate _instance =
      DefaultAssetsPickerTextDelegate._internal();

  @override
  String confirm = 'confirm';

  @override
  String cancel = 'cancel';

  @override
  String edit = 'edit';

  @override
  String emptyPlaceHolder = 'emptyPlaceHolder';

  @override
  String gifIndicator = 'GIF';

  @override
  String heicNotSupported = 'heicNotSupported';

  @override
  String loadFailed = 'loadFailed';

  @override
  String original = 'original';

  @override
  String preview = 'preview';

  @override
  String select = 'select';

  @override
  String unSupportedAssetType = 'unSupportedAssetType';

  @override
  String durationIndicatorBuilder(Duration duration) {
    const String separator = ':';
    final String minute = duration.inMinutes.toString().padLeft(2, '0');
    final String second =
        ((duration - Duration(minutes: duration.inMinutes)).inSeconds)
            .toString()
            .padLeft(2, '0');
    return '$minute$separator$second';
  }
}

/// [AssetsPickerTextDelegate] implements with English.
class EnglishTextDelegate implements AssetsPickerTextDelegate {
  factory EnglishTextDelegate() => _instance;

  EnglishTextDelegate._internal();

  static final EnglishTextDelegate _instance = EnglishTextDelegate._internal();

  @override
  String confirm = 'Confirm';

  @override
  String cancel = 'Cancel';

  @override
  String edit = 'Edit';

  @override
  String emptyPlaceHolder = 'Nothing here...';

  @override
  String gifIndicator = 'GIF';

  @override
  String heicNotSupported = 'Unsupported HEIC asset type.';

  @override
  String loadFailed = 'Load failed';

  @override
  String original = 'Origin';

  @override
  String preview = 'Preview';

  @override
  String select = 'Select';

  @override
  String unSupportedAssetType = 'Unsupported HEIC asset type.';

  @override
  String durationIndicatorBuilder(Duration duration) {
    const String separator = ':';
    final String minute = duration.inMinutes.toString().padLeft(2, '0');
    final String second =
        ((duration - Duration(minutes: duration.inMinutes)).inSeconds)
            .toString()
            .padLeft(2, '0');
    return '$minute$separator$second';
  }
}
