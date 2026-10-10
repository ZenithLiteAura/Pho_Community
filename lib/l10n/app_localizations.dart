import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @local.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get local;

  /// No description provided for @cloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get cloud;

  /// No description provided for @sync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get sync;

  /// No description provided for @cloudSync.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync'**
  String get cloudSync;

  /// No description provided for @localFolder.
  ///
  /// In en, this message translates to:
  /// **'Local folder'**
  String get localFolder;

  /// No description provided for @cloudStorage.
  ///
  /// In en, this message translates to:
  /// **'Cloud storage'**
  String get cloudStorage;

  /// No description provided for @backgroundSync.
  ///
  /// In en, this message translates to:
  /// **'Auto Sync'**
  String get backgroundSync;

  /// No description provided for @notSync.
  ///
  /// In en, this message translates to:
  /// **'not sync'**
  String get notSync;

  /// No description provided for @unsynchronizedPhotos.
  ///
  /// In en, this message translates to:
  /// **'Unsynchronized photos'**
  String get unsynchronizedPhotos;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @photos.
  ///
  /// In en, this message translates to:
  /// **'photos'**
  String get photos;

  /// No description provided for @deleteThisPhoto.
  ///
  /// In en, this message translates to:
  /// **'Delete this photo?'**
  String get deleteThisPhoto;

  /// No description provided for @deleteThisPhotos.
  ///
  /// In en, this message translates to:
  /// **'Delete this photos?'**
  String get deleteThisPhotos;

  /// No description provided for @cantBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This action can\'t be undone'**
  String get cantBeUndone;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'success'**
  String get success;

  /// No description provided for @pics.
  ///
  /// In en, this message translates to:
  /// **'pics'**
  String get pics;

  /// No description provided for @choose.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get choose;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading'**
  String get uploading;

  /// No description provided for @downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get downloading;

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get uploadFailed;

  /// No description provided for @retrying.
  ///
  /// In en, this message translates to:
  /// **'Retrying'**
  String get retrying;

  /// No description provided for @uploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get uploaded;

  /// No description provided for @notUploaded.
  ///
  /// In en, this message translates to:
  /// **'Not uploaded'**
  String get notUploaded;

  /// No description provided for @chooseAlbum.
  ///
  /// In en, this message translates to:
  /// **'Choose album'**
  String get chooseAlbum;

  /// No description provided for @storageSetting.
  ///
  /// In en, this message translates to:
  /// **'Storage setting'**
  String get storageSetting;

  /// No description provided for @remoteStorageType.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get remoteStorageType;

  /// No description provided for @storageProtocol.
  ///
  /// In en, this message translates to:
  /// **'Storage protocol'**
  String get storageProtocol;

  /// No description provided for @aboutStorage.
  ///
  /// In en, this message translates to:
  /// **'About storage'**
  String get aboutStorage;

  /// No description provided for @dockStyle.
  ///
  /// In en, this message translates to:
  /// **'Bottom dock style'**
  String get dockStyle;

  /// No description provided for @dockStyleFrosted.
  ///
  /// In en, this message translates to:
  /// **'Frosted glass'**
  String get dockStyleFrosted;

  /// No description provided for @dockStyleMica.
  ///
  /// In en, this message translates to:
  /// **'Mica'**
  String get dockStyleMica;

  /// No description provided for @dockStyleSolid.
  ///
  /// In en, this message translates to:
  /// **'Solid'**
  String get dockStyleSolid;

  /// No description provided for @dockOpacity.
  ///
  /// In en, this message translates to:
  /// **'Dock opacity'**
  String get dockOpacity;

  /// No description provided for @dockOpacityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get dockOpacityHigh;

  /// No description provided for @dockOpacityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get dockOpacityMedium;

  /// No description provided for @dockOpacityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get dockOpacityLow;

  /// No description provided for @dockBlur.
  ///
  /// In en, this message translates to:
  /// **'Dock blur'**
  String get dockBlur;

  /// No description provided for @dockBlurLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get dockBlurLight;

  /// No description provided for @dockBlurMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get dockBlurMedium;

  /// No description provided for @dockBlurStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get dockBlurStrong;

  /// No description provided for @appearanceAndThemeDesc.
  ///
  /// In en, this message translates to:
  /// **'Theme style, dark mode and dock customization'**
  String get appearanceAndThemeDesc;

  /// No description provided for @samvbaServerAddress.
  ///
  /// In en, this message translates to:
  /// **'Samba server address'**
  String get samvbaServerAddress;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @rootPath.
  ///
  /// In en, this message translates to:
  /// **'Root path(Your photos will be uploaded to this path)'**
  String get rootPath;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get optional;

  /// No description provided for @testStorage.
  ///
  /// In en, this message translates to:
  /// **'Test storage'**
  String get testStorage;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @enableBackgroundSync.
  ///
  /// In en, this message translates to:
  /// **'Enable background sync'**
  String get enableBackgroundSync;

  /// No description provided for @syncOnlyOnWifi.
  ///
  /// In en, this message translates to:
  /// **'Sync only on WIFI'**
  String get syncOnlyOnWifi;

  /// No description provided for @syncInterval.
  ///
  /// In en, this message translates to:
  /// **'Sync interval'**
  String get syncInterval;

  /// No description provided for @minite.
  ///
  /// In en, this message translates to:
  /// **'minite'**
  String get minite;

  /// No description provided for @hour.
  ///
  /// In en, this message translates to:
  /// **'hour'**
  String get hour;

  /// No description provided for @day.
  ///
  /// In en, this message translates to:
  /// **'day'**
  String get day;

  /// No description provided for @week.
  ///
  /// In en, this message translates to:
  /// **'week'**
  String get week;

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'month'**
  String get month;

  /// No description provided for @year.
  ///
  /// In en, this message translates to:
  /// **'year'**
  String get year;

  /// No description provided for @chineseday.
  ///
  /// In en, this message translates to:
  /// **''**
  String get chineseday;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @permissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied'**
  String get permissionDenied;

  /// No description provided for @setLocalFirst.
  ///
  /// In en, this message translates to:
  /// **'Please set local folder first'**
  String get setLocalFirst;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get downloadFailed;

  /// No description provided for @storageNotSetted.
  ///
  /// In en, this message translates to:
  /// **'Remote storage is not setted,please set it first'**
  String get storageNotSetted;

  /// No description provided for @successfullyUpload.
  ///
  /// In en, this message translates to:
  /// **'Successfully upload'**
  String get successfullyUpload;

  /// No description provided for @testSuccess.
  ///
  /// In en, this message translates to:
  /// **'Test success,you can save now'**
  String get testSuccess;

  /// No description provided for @connectFailed.
  ///
  /// In en, this message translates to:
  /// **'Storage connection failed'**
  String get connectFailed;

  /// No description provided for @selectRoot.
  ///
  /// In en, this message translates to:
  /// **'Select root path'**
  String get selectRoot;

  /// No description provided for @currentPath.
  ///
  /// In en, this message translates to:
  /// **'Current path'**
  String get currentPath;

  /// No description provided for @refreshingPleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Comparing your local and cloud photos, the process may take longer if it\'s the first time running or if there are a large number of photos. Please be patient and wait.......'**
  String get refreshingPleaseWait;

  /// No description provided for @setRemoteStroage.
  ///
  /// In en, this message translates to:
  /// **'Please set cloud storage first'**
  String get setRemoteStroage;

  /// No description provided for @needPermision.
  ///
  /// In en, this message translates to:
  /// **'Need permission to access photos'**
  String get needPermision;

  /// No description provided for @gotoSystemSetting.
  ///
  /// In en, this message translates to:
  /// **'To browse the system album, you need to grant access permissions to the photo library. If necessary, please go to system settings to grant permission for accessing the photo library.'**
  String get gotoSystemSetting;

  /// No description provided for @openSetting.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSetting;

  /// No description provided for @advancedSetting.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advancedSetting;

  /// No description provided for @goToSet.
  ///
  /// In en, this message translates to:
  /// **'Go to set'**
  String get goToSet;

  /// No description provided for @streamFallbackDownload.
  ///
  /// In en, this message translates to:
  /// **'Streaming failed, downloading for playback'**
  String get streamFallbackDownload;

  /// No description provided for @dataDirWarning.
  ///
  /// In en, this message translates to:
  /// **'Modifying the directory structure will only change files uploaded in the future, it will not modify files that have already been uploaded.'**
  String get dataDirWarning;

  /// No description provided for @dirType01.
  ///
  /// In en, this message translates to:
  /// **'Multilevel by date'**
  String get dirType01;

  /// No description provided for @dirType02.
  ///
  /// In en, this message translates to:
  /// **'Single level by date'**
  String get dirType02;

  /// No description provided for @tapToSet.
  ///
  /// In en, this message translates to:
  /// **'Tap to set'**
  String get tapToSet;

  /// No description provided for @longPressToCancel.
  ///
  /// In en, this message translates to:
  /// **'Long press to cancel'**
  String get longPressToCancel;

  /// No description provided for @jumpTo.
  ///
  /// In en, this message translates to:
  /// **'Jump to'**
  String get jumpTo;

  /// No description provided for @jumpToByDate.
  ///
  /// In en, this message translates to:
  /// **'Jump to'**
  String get jumpToByDate;

  /// No description provided for @onlyCamera.
  ///
  /// In en, this message translates to:
  /// **'Only camera'**
  String get onlyCamera;

  /// No description provided for @unlockAllAdvancedFeatures.
  ///
  /// In en, this message translates to:
  /// **'Unlock all features'**
  String get unlockAllAdvancedFeatures;

  /// No description provided for @browseInRecents.
  ///
  /// In en, this message translates to:
  /// **'You can browse in recents'**
  String get browseInRecents;

  /// No description provided for @failedTooMany.
  ///
  /// In en, this message translates to:
  /// **'Failed too many times,stop syncing'**
  String get failedTooMany;

  /// No description provided for @refreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing photos,please wait...'**
  String get refreshing;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @desktopStorageSettingDesc.
  ///
  /// In en, this message translates to:
  /// **'Set up network storage to browse the photos you\'ve backed up using Pho Next'**
  String get desktopStorageSettingDesc;

  /// No description provided for @zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoomIn;

  /// No description provided for @zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoomOut;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get appVersion;

  /// No description provided for @releaseStorage.
  ///
  /// In en, this message translates to:
  /// **'Release storage'**
  String get releaseStorage;

  /// No description provided for @deleteSynced.
  ///
  /// In en, this message translates to:
  /// **'Delete synced photos'**
  String get deleteSynced;

  /// No description provided for @youHaveSynced.
  ///
  /// In en, this message translates to:
  /// **'You have synced'**
  String get youHaveSynced;

  /// No description provided for @photosInCloud.
  ///
  /// In en, this message translates to:
  /// **'photos or videos'**
  String get photosInCloud;

  /// No description provided for @canDeleteNow.
  ///
  /// In en, this message translates to:
  /// **'You can now delete them to save space'**
  String get canDeleteNow;

  /// No description provided for @canBrowserAnyTime.
  ///
  /// In en, this message translates to:
  /// **'You can browse them in original quality in cloud storage at any time'**
  String get canBrowserAnyTime;

  /// No description provided for @pleaseConfirmBeforeDelete.
  ///
  /// In en, this message translates to:
  /// **'Please make sure you have backed up these photos in cloud storage before deleting them, otherwise they will not be recoverable after deletion'**
  String get pleaseConfirmBeforeDelete;

  /// No description provided for @installHEVCExtention.
  ///
  /// In en, this message translates to:
  /// **'If HEIC or HEVC formats cannot be displayed correctly, please install \"HEVC Video Extension\" in the Microsoft Store'**
  String get installHEVCExtention;

  /// No description provided for @openMSStore.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get openMSStore;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get clearCache;

  /// No description provided for @clearCacheDescription.
  ///
  /// In en, this message translates to:
  /// **'This operation will only clear the image cache and will not delete any of your configurations. Are you sure you want to clear the cache?'**
  String get clearCacheDescription;

  /// No description provided for @clearCacheSuccess.
  ///
  /// In en, this message translates to:
  /// **'Clear cache success'**
  String get clearCacheSuccess;

  /// No description provided for @clearCacheFailed.
  ///
  /// In en, this message translates to:
  /// **'Clear cache failed'**
  String get clearCacheFailed;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @noLocalPhotos.
  ///
  /// In en, this message translates to:
  /// **'No photos found'**
  String get noLocalPhotos;

  /// No description provided for @noCloudPhotos.
  ///
  /// In en, this message translates to:
  /// **'No cloud photos'**
  String get noCloudPhotos;

  /// No description provided for @refreshUnsynchronizedPhotos.
  ///
  /// In en, this message translates to:
  /// **'Refresh unsynchronized photos'**
  String get refreshUnsynchronizedPhotos;

  /// No description provided for @onboardingWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Pho Next'**
  String get onboardingWelcome;

  /// No description provided for @onboardingWelcomeDesc.
  ///
  /// In en, this message translates to:
  /// **'Your serverless photo sync tool'**
  String get onboardingWelcomeDesc;

  /// No description provided for @onboardingSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync to your storage'**
  String get onboardingSyncTitle;

  /// No description provided for @onboardingSyncDesc.
  ///
  /// In en, this message translates to:
  /// **'Supports SMB, WebDAV and NFS. Photos organized by date automatically'**
  String get onboardingSyncDesc;

  /// No description provided for @onboardingPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your data, your control'**
  String get onboardingPrivacyTitle;

  /// No description provided for @onboardingPrivacyDesc.
  ///
  /// In en, this message translates to:
  /// **'No server, no database. Files stored directly in your network storage'**
  String get onboardingPrivacyDesc;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingGetStarted;

  /// No description provided for @onboardingPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Photo access needed'**
  String get onboardingPermissionTitle;

  /// No description provided for @onboardingPermissionDesc.
  ///
  /// In en, this message translates to:
  /// **'Pho Next needs access to your photo library to browse and sync photos'**
  String get onboardingPermissionDesc;

  /// No description provided for @onboardingGrantPermission.
  ///
  /// In en, this message translates to:
  /// **'Grant permission'**
  String get onboardingGrantPermission;

  /// No description provided for @onboardingLater.
  ///
  /// In en, this message translates to:
  /// **'Set up later'**
  String get onboardingLater;

  /// No description provided for @onboardingStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up cloud storage (optional)'**
  String get onboardingStorageTitle;

  /// No description provided for @onboardingStorageDesc.
  ///
  /// In en, this message translates to:
  /// **'You can set up now or later in Settings'**
  String get onboardingStorageDesc;

  /// No description provided for @onboardingSetupStorage.
  ///
  /// In en, this message translates to:
  /// **'Set up storage'**
  String get onboardingSetupStorage;

  /// No description provided for @onboardingComplete.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get onboardingComplete;

  /// No description provided for @settingsBasic.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get settingsBasic;

  /// No description provided for @settingsUtilities.
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get settingsUtilities;

  /// No description provided for @monthlyPlan.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthlyPlan;

  /// No description provided for @yearlyPlan.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearlyPlan;

  /// No description provided for @lifetimePlan.
  ///
  /// In en, this message translates to:
  /// **'Lifetime'**
  String get lifetimePlan;

  /// No description provided for @perMonth.
  ///
  /// In en, this message translates to:
  /// **'{price}/mo'**
  String perMonth(Object price);

  /// No description provided for @perYear.
  ///
  /// In en, this message translates to:
  /// **'{price}/yr'**
  String perYear(Object price);

  /// No description provided for @oneTime.
  ///
  /// In en, this message translates to:
  /// **'One-time'**
  String get oneTime;

  /// No description provided for @savePercent.
  ///
  /// In en, this message translates to:
  /// **'Save {percent}%'**
  String savePercent(Object percent);

  /// No description provided for @recommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get recommended;

  /// No description provided for @bestValue.
  ///
  /// In en, this message translates to:
  /// **'Best value'**
  String get bestValue;

  /// No description provided for @mostFlexible.
  ///
  /// In en, this message translates to:
  /// **'Most flexible'**
  String get mostFlexible;

  /// No description provided for @subscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get subscribe;

  /// No description provided for @termsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get termsOfUse;

  /// No description provided for @iosBackgroundSyncDescription.
  ///
  /// In en, this message translates to:
  /// **'iOS background sync is automatically scheduled by the system when charging, no manual interval setting required'**
  String get iosBackgroundSyncDescription;

  /// No description provided for @notificationDenied.
  ///
  /// In en, this message translates to:
  /// **'Notification permission not granted, sync works but no alerts'**
  String get notificationDenied;

  /// No description provided for @backgroundRefreshDisabledTitle.
  ///
  /// In en, this message translates to:
  /// **'Background App Refresh is off'**
  String get backgroundRefreshDisabledTitle;

  /// No description provided for @backgroundRefreshDisabledDesc.
  ///
  /// In en, this message translates to:
  /// **'Background sync cannot be triggered. Please go to Settings -> Pho Next to enable Background App Refresh, then go to Settings -> General -> Background App Refresh to confirm it\'s enabled globally'**
  String get backgroundRefreshDisabledDesc;

  /// No description provided for @backgroundRefreshDisabledAction.
  ///
  /// In en, this message translates to:
  /// **'Open Pho Next Settings'**
  String get backgroundRefreshDisabledAction;

  /// No description provided for @bgSyncSuccessNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Pho Next Background Sync'**
  String get bgSyncSuccessNotificationTitle;

  /// No description provided for @bgSyncSuccessNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'Successfully synced {count} photos'**
  String bgSyncSuccessNotificationBody(int count);

  /// No description provided for @bgSyncSuccessNotificationBodyWithFailures.
  ///
  /// In en, this message translates to:
  /// **'Successfully synced {succeeded} photos ({failed} failed)'**
  String bgSyncSuccessNotificationBodyWithFailures(int succeeded, int failed);

  /// No description provided for @bgSyncInProgressNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Pho Next Syncing…'**
  String get bgSyncInProgressNotificationTitle;

  /// No description provided for @bgSyncInProgressNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'Syncing photos in the background'**
  String get bgSyncInProgressNotificationBody;

  /// No description provided for @notificationPermissionStatus.
  ///
  /// In en, this message translates to:
  /// **'Notification permission'**
  String get notificationPermissionStatus;

  /// No description provided for @notificationPermissionGranted.
  ///
  /// In en, this message translates to:
  /// **'Granted'**
  String get notificationPermissionGranted;

  /// No description provided for @notificationPermissionNotGranted.
  ///
  /// In en, this message translates to:
  /// **'Not granted — tap to request'**
  String get notificationPermissionNotGranted;

  /// No description provided for @parallelUploadCount.
  ///
  /// In en, this message translates to:
  /// **'Parallel upload count'**
  String get parallelUploadCount;

  /// No description provided for @syncMode.
  ///
  /// In en, this message translates to:
  /// **'Sync mode'**
  String get syncMode;

  /// No description provided for @syncModeInterval.
  ///
  /// In en, this message translates to:
  /// **'Interval'**
  String get syncModeInterval;

  /// No description provided for @syncModeSchedule.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get syncModeSchedule;

  /// No description provided for @scheduledSyncTimes.
  ///
  /// In en, this message translates to:
  /// **'Scheduled sync times (daily)'**
  String get scheduledSyncTimes;

  /// No description provided for @addTime.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addTime;

  /// No description provided for @noScheduleTimes.
  ///
  /// In en, this message translates to:
  /// **'No scheduled times yet. Add one to enable scheduled sync.'**
  String get noScheduleTimes;

  /// No description provided for @accountAndSync.
  ///
  /// In en, this message translates to:
  /// **'Account & Sync'**
  String get accountAndSync;

  /// No description provided for @storageAndBackup.
  ///
  /// In en, this message translates to:
  /// **'Storage & Backup'**
  String get storageAndBackup;

  /// No description provided for @notificationsAndPermissions.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsAndPermissions;

  /// No description provided for @appearanceAndTheme.
  ///
  /// In en, this message translates to:
  /// **'Appearance & Theme'**
  String get appearanceAndTheme;

  /// No description provided for @themeStyle.
  ///
  /// In en, this message translates to:
  /// **'Theme style'**
  String get themeStyle;

  /// No description provided for @themeMiuix.
  ///
  /// In en, this message translates to:
  /// **'MIUIX'**
  String get themeMiuix;

  /// No description provided for @themeMaterial3.
  ///
  /// In en, this message translates to:
  /// **'Material 3'**
  String get themeMaterial3;

  /// No description provided for @themeMiuixDesc.
  ///
  /// In en, this message translates to:
  /// **'HyperOS style: rounded cards, compact layout, Xiaomi blue accent'**
  String get themeMiuixDesc;

  /// No description provided for @themeMaterial3Desc.
  ///
  /// In en, this message translates to:
  /// **'Material You: dynamic color, spacious layout'**
  String get themeMaterial3Desc;

  /// No description provided for @galleryColumnCount.
  ///
  /// In en, this message translates to:
  /// **'Gallery columns'**
  String get galleryColumnCount;

  /// No description provided for @backgroundSyncSettings.
  ///
  /// In en, this message translates to:
  /// **'Background sync settings'**
  String get backgroundSyncSettings;

  /// No description provided for @storageLocationDesc.
  ///
  /// In en, this message translates to:
  /// **'Photos are stored directly on your network storage (SMB / WebDAV / NFS). No server, no database.'**
  String get storageLocationDesc;

  /// No description provided for @appLicense.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get appLicense;

  /// No description provided for @licenseText.
  ///
  /// In en, this message translates to:
  /// **'GPL-3.0 License. Pho Next is an open-source photo sync tool.'**
  String get licenseText;

  /// No description provided for @backupToFile.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get backupToFile;

  /// No description provided for @backupDesc.
  ///
  /// In en, this message translates to:
  /// **'Export all settings (including cloud storage credentials) as a zip archive'**
  String get backupDesc;

  /// No description provided for @backupSuccess.
  ///
  /// In en, this message translates to:
  /// **'Backup saved'**
  String get backupSuccess;

  /// No description provided for @backupFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup failed'**
  String get backupFailed;

  /// No description provided for @restoreFromBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreFromBackup;

  /// No description provided for @restoreDesc.
  ///
  /// In en, this message translates to:
  /// **'Restore settings from a backup zip archive'**
  String get restoreDesc;

  /// No description provided for @restoreConfirm.
  ///
  /// In en, this message translates to:
  /// **'Restore will overwrite the current settings. Continue?'**
  String get restoreConfirm;

  /// No description provided for @restoreSuccess.
  ///
  /// In en, this message translates to:
  /// **'Restored. Please restart the app to apply.'**
  String get restoreSuccess;

  /// No description provided for @restoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed'**
  String get restoreFailed;

  /// No description provided for @noBackupFile.
  ///
  /// In en, this message translates to:
  /// **'No backup file selected'**
  String get noBackupFile;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get darkMode;

  /// No description provided for @darkModeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get darkModeLight;

  /// No description provided for @darkModeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkModeDark;

  /// No description provided for @darkModeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get darkModeSystem;

  /// No description provided for @backupStorage.
  ///
  /// In en, this message translates to:
  /// **'Backup storage (optional)'**
  String get backupStorage;

  /// No description provided for @testPrimaryStorage.
  ///
  /// In en, this message translates to:
  /// **'Test primary'**
  String get testPrimaryStorage;

  /// No description provided for @savePrimaryStorage.
  ///
  /// In en, this message translates to:
  /// **'Save primary'**
  String get savePrimaryStorage;

  /// No description provided for @testBackupStorage.
  ///
  /// In en, this message translates to:
  /// **'Test backup'**
  String get testBackupStorage;

  /// No description provided for @saveBackupStorage.
  ///
  /// In en, this message translates to:
  /// **'Save backup'**
  String get saveBackupStorage;

  /// No description provided for @backupStorageDesc.
  ///
  /// In en, this message translates to:
  /// **'Dual WebDAV: uploads automatically fall back to the backup when the primary fails'**
  String get backupStorageDesc;

  /// No description provided for @skipTLS.
  ///
  /// In en, this message translates to:
  /// **'Skip TLS Verification'**
  String get skipTLS;

  /// No description provided for @backupRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get backupRestore;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @primaryStorage.
  ///
  /// In en, this message translates to:
  /// **'Primary Storage'**
  String get primaryStorage;

  /// No description provided for @backupUrl.
  ///
  /// In en, this message translates to:
  /// **'Backup URL'**
  String get backupUrl;

  /// No description provided for @backupUrlEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter the backup URL first'**
  String get backupUrlEmpty;

  /// No description provided for @backupRootPath.
  ///
  /// In en, this message translates to:
  /// **'Backup root path'**
  String get backupRootPath;

  /// No description provided for @allowUntrusted.
  ///
  /// In en, this message translates to:
  /// **'Allow untrusted certificates'**
  String get allowUntrusted;

  /// No description provided for @errorLabel.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get errorLabel;

  /// No description provided for @localView.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get localView;

  /// No description provided for @cloudView.
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get cloudView;

  /// No description provided for @hevcExtention.
  ///
  /// In en, this message translates to:
  /// **'HEVC Extension'**
  String get hevcExtention;

  /// No description provided for @syncSettings.
  ///
  /// In en, this message translates to:
  /// **'Sync settings'**
  String get syncSettings;

  /// No description provided for @dataManagement.
  ///
  /// In en, this message translates to:
  /// **'Data management'**
  String get dataManagement;

  /// No description provided for @logAndDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Logs & diagnostics'**
  String get logAndDiagnostics;

  /// No description provided for @logDesc.
  ///
  /// In en, this message translates to:
  /// **'Records only the logs produced after you start collecting. Stopping saves the session; the latest 8 are kept.'**
  String get logDesc;

  /// No description provided for @logStartCollect.
  ///
  /// In en, this message translates to:
  /// **'Start collecting'**
  String get logStartCollect;

  /// No description provided for @logStopCollect.
  ///
  /// In en, this message translates to:
  /// **'Stop & save'**
  String get logStopCollect;

  /// No description provided for @logCollecting.
  ///
  /// In en, this message translates to:
  /// **'Collecting'**
  String get logCollecting;

  /// No description provided for @logIdle.
  ///
  /// In en, this message translates to:
  /// **'Not collecting'**
  String get logIdle;

  /// No description provided for @logLevel.
  ///
  /// In en, this message translates to:
  /// **'Log level'**
  String get logLevel;

  /// No description provided for @logLevelHint.
  ///
  /// In en, this message translates to:
  /// **'and above'**
  String get logLevelHint;

  /// No description provided for @logPreview.
  ///
  /// In en, this message translates to:
  /// **'Live log'**
  String get logPreview;

  /// No description provided for @logPreviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'Logs produced after starting will show up here'**
  String get logPreviewEmpty;

  /// No description provided for @logExport.
  ///
  /// In en, this message translates to:
  /// **'Export log'**
  String get logExport;

  /// No description provided for @logExportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Exported'**
  String get logExportSuccess;

  /// No description provided for @logExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get logExportFailed;

  /// No description provided for @logSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save the log'**
  String get logSaveFailed;

  /// No description provided for @logHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get logHistory;

  /// No description provided for @logHistoryKeep.
  ///
  /// In en, this message translates to:
  /// **'Keeps the latest'**
  String get logHistoryKeep;

  /// No description provided for @logHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved sessions yet'**
  String get logHistoryEmpty;

  /// No description provided for @logClearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get logClearHistory;

  /// No description provided for @logEntries.
  ///
  /// In en, this message translates to:
  /// **'entries'**
  String get logEntries;

  /// No description provided for @syncNotify.
  ///
  /// In en, this message translates to:
  /// **'Sync notifications'**
  String get syncNotify;

  /// No description provided for @syncCompleteNotify.
  ///
  /// In en, this message translates to:
  /// **'Sync complete notification'**
  String get syncCompleteNotify;

  /// No description provided for @syncCompleteNotifyDesc.
  ///
  /// In en, this message translates to:
  /// **'Send a notification when sync finishes (silent if disabled)'**
  String get syncCompleteNotifyDesc;

  /// No description provided for @stopping.
  ///
  /// In en, this message translates to:
  /// **'Stopping...'**
  String get stopping;

  /// No description provided for @stopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get stopped;

  /// No description provided for @encryption.
  ///
  /// In en, this message translates to:
  /// **'Encryption'**
  String get encryption;

  /// No description provided for @columns.
  ///
  /// In en, this message translates to:
  /// **'columns'**
  String get columns;

  /// No description provided for @galleryColumnCountDesc.
  ///
  /// In en, this message translates to:
  /// **'Slide to adjust the gallery column count (2-10)'**
  String get galleryColumnCountDesc;

  /// No description provided for @activeConfig.
  ///
  /// In en, this message translates to:
  /// **'Current profile'**
  String get activeConfig;

  /// No description provided for @newConfig.
  ///
  /// In en, this message translates to:
  /// **'New profile'**
  String get newConfig;

  /// No description provided for @renameConfig.
  ///
  /// In en, this message translates to:
  /// **'Rename profile'**
  String get renameConfig;

  /// No description provided for @deleteConfig.
  ///
  /// In en, this message translates to:
  /// **'Delete profile'**
  String get deleteConfig;

  /// No description provided for @configName.
  ///
  /// In en, this message translates to:
  /// **'Profile name'**
  String get configName;

  /// No description provided for @configNamePrefix.
  ///
  /// In en, this message translates to:
  /// **'Profile '**
  String get configNamePrefix;

  /// No description provided for @configNameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Profile name cannot be empty'**
  String get configNameEmpty;

  /// No description provided for @deleteConfigConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this profile? This cannot be undone.'**
  String get deleteConfigConfirm;

  /// No description provided for @noConfigYet.
  ///
  /// In en, this message translates to:
  /// **'No profiles yet — tap \"New profile\"'**
  String get noConfigYet;

  /// No description provided for @configNotReady.
  ///
  /// In en, this message translates to:
  /// **'Profile is missing URL or root path'**
  String get configNotReady;

  /// No description provided for @configSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved'**
  String get configSaved;

  /// No description provided for @motion.
  ///
  /// In en, this message translates to:
  /// **'Motion'**
  String get motion;

  /// No description provided for @motionFull.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get motionFull;

  /// No description provided for @motionSimple.
  ///
  /// In en, this message translates to:
  /// **'Simple'**
  String get motionSimple;

  /// No description provided for @motionOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get motionOff;

  /// No description provided for @motionDescFull.
  ///
  /// In en, this message translates to:
  /// **'Expands from your finger, bloom follows it, overlays pull down to dismiss with a jelly bounce'**
  String get motionDescFull;

  /// No description provided for @motionDescSimple.
  ///
  /// In en, this message translates to:
  /// **'Expands from your finger with a light bloom; overlays pull down to dismiss'**
  String get motionDescSimple;

  /// No description provided for @motionDescOff.
  ///
  /// In en, this message translates to:
  /// **'No expand morph or bloom; overlays just appear (most efficient)'**
  String get motionDescOff;

  /// No description provided for @startupNoticeWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Pho Next!'**
  String get startupNoticeWelcomeTitle;

  /// No description provided for @startupNoticeWelcomeBody1.
  ///
  /// In en, this message translates to:
  /// **'Pho is a serverless, account-free photo browsing and syncing app — photos are stored in your own storage by directory, supporting multiple backends such as SMB / WebDAV / NFS, and you have full control over your data.'**
  String get startupNoticeWelcomeBody1;

  /// No description provided for @startupNoticeWelcomeBody2.
  ///
  /// In en, this message translates to:
  /// **'This repository is the open source community edition, currently only providing Android APK, welcome to download and experience. If you encounter problems, feel free to open an Issue to give feedback, and you are also welcome to submit suggestions~'**
  String get startupNoticeWelcomeBody2;

  /// No description provided for @startupNoticeWelcomeWarning.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Remember to back up your photos before trying! You are responsible for the consequences caused by operational errors or lack of backup, thank you for your understanding'**
  String get startupNoticeWelcomeWarning;

  /// No description provided for @startupNoticeSecondsLeft.
  ///
  /// In en, this message translates to:
  /// **'s until you can close'**
  String get startupNoticeSecondsLeft;

  /// No description provided for @startupNoticeCanCloseNow.
  ///
  /// In en, this message translates to:
  /// **'You can close this now'**
  String get startupNoticeCanCloseNow;

  /// No description provided for @startupNoticeClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get startupNoticeClose;

  /// No description provided for @openInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get openInBrowser;

  /// No description provided for @aboutOriginalAuthor.
  ///
  /// In en, this message translates to:
  /// **'Original author'**
  String get aboutOriginalAuthor;

  /// No description provided for @aboutCommunityBuild.
  ///
  /// In en, this message translates to:
  /// **'Community build'**
  String get aboutCommunityBuild;

  /// No description provided for @aboutLicense.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get aboutLicense;

  /// No description provided for @advancedSettings.
  ///
  /// In en, this message translates to:
  /// **'Advanced settings'**
  String get advancedSettings;

  /// No description provided for @disableStartupNotice.
  ///
  /// In en, this message translates to:
  /// **'Disable startup notice'**
  String get disableStartupNotice;

  /// No description provided for @disableStartupNoticeDesc.
  ///
  /// In en, this message translates to:
  /// **'When enabled, the copyright notice will no longer appear from the next launch'**
  String get disableStartupNoticeDesc;

  /// No description provided for @checkForUpdate.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdate;

  /// No description provided for @checkForUpdateDesc.
  ///
  /// In en, this message translates to:
  /// **'Check GitHub for a newer release'**
  String get checkForUpdateDesc;

  /// No description provided for @checkingUpdate.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get checkingUpdate;

  /// No description provided for @updateLatest.
  ///
  /// In en, this message translates to:
  /// **'You are up to date'**
  String get updateLatest;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Update check failed - please check your network and retry'**
  String get updateCheckFailed;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailableTitle;

  /// No description provided for @updateAvailableBody.
  ///
  /// In en, this message translates to:
  /// **'A newer release is available on GitHub'**
  String get updateAvailableBody;

  /// No description provided for @updateReleaseNotes.
  ///
  /// In en, this message translates to:
  /// **'Release notes'**
  String get updateReleaseNotes;

  /// No description provided for @updateGoDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get updateGoDownload;

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @autoCheckUpdate.
  ///
  /// In en, this message translates to:
  /// **'Check for updates at startup'**
  String get autoCheckUpdate;

  /// No description provided for @autoCheckUpdateDesc.
  ///
  /// In en, this message translates to:
  /// **'Check GitHub for a newer release at startup and notify you'**
  String get autoCheckUpdateDesc;

  /// No description provided for @announcementTitle.
  ///
  /// In en, this message translates to:
  /// **'Announcement'**
  String get announcementTitle;

  /// No description provided for @announcementLevelInfo.
  ///
  /// In en, this message translates to:
  /// **'Notice'**
  String get announcementLevelInfo;

  /// No description provided for @announcementLevelWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get announcementLevelWarning;

  /// No description provided for @announcementLevelCritical.
  ///
  /// In en, this message translates to:
  /// **'Important'**
  String get announcementLevelCritical;

  /// No description provided for @announcementCriticalHint.
  ///
  /// In en, this message translates to:
  /// **'This is an important notice - please confirm with the button below.'**
  String get announcementCriticalHint;

  /// No description provided for @announcementGoTo.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get announcementGoTo;

  /// No description provided for @announcementOk.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get announcementOk;

  /// No description provided for @startupNoticeHowToDisable.
  ///
  /// In en, this message translates to:
  /// **'Don\'t want to see this on every launch? Go to Settings → About → Advanced settings and turn on \"Disable startup notice\".'**
  String get startupNoticeHowToDisable;

  /// No description provided for @devOptions.
  ///
  /// In en, this message translates to:
  /// **'Developer options'**
  String get devOptions;

  /// No description provided for @devOptionsDesc.
  ///
  /// In en, this message translates to:
  /// **'Debugging and publishing tools for maintainers only'**
  String get devOptionsDesc;

  /// No description provided for @devUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Developer options unlocked'**
  String get devUnlocked;

  /// No description provided for @devPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Developer password'**
  String get devPasswordTitle;

  /// No description provided for @devPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get devPasswordHint;

  /// No description provided for @devPasswordWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong password'**
  String get devPasswordWrong;

  /// No description provided for @devPasswordConfirm.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get devPasswordConfirm;

  /// No description provided for @devSectionAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'Announcement'**
  String get devSectionAnnouncement;

  /// No description provided for @devProbeSources.
  ///
  /// In en, this message translates to:
  /// **'Test fetching announcements (per source)'**
  String get devProbeSources;

  /// No description provided for @devPreviewAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'Preview announcement dialog'**
  String get devPreviewAnnouncement;

  /// No description provided for @devResetSeen.
  ///
  /// In en, this message translates to:
  /// **'Reset read-announcement records'**
  String get devResetSeen;

  /// No description provided for @devShowStartupNoticeNow.
  ///
  /// In en, this message translates to:
  /// **'Show the copyright notice now'**
  String get devShowStartupNoticeNow;

  /// No description provided for @devForceStartupNotice.
  ///
  /// In en, this message translates to:
  /// **'Re-enable the startup notice'**
  String get devForceStartupNotice;

  /// No description provided for @devSectionPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish announcement'**
  String get devSectionPublish;

  /// No description provided for @devGithubToken.
  ///
  /// In en, this message translates to:
  /// **'GitHub token (stored on this device only)'**
  String get devGithubToken;

  /// No description provided for @devAnnouncementId.
  ///
  /// In en, this message translates to:
  /// **'Announcement id'**
  String get devAnnouncementId;

  /// No description provided for @devLevel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get devLevel;

  /// No description provided for @devGenerateOnly.
  ///
  /// In en, this message translates to:
  /// **'Build JSON and copy'**
  String get devGenerateOnly;

  /// No description provided for @devPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get devPublish;

  /// No description provided for @devDisableAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'Take the announcement down (enabled=false)'**
  String get devDisableAnnouncement;

  /// No description provided for @devSectionUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update check'**
  String get devSectionUpdate;

  /// No description provided for @devTestUpdateCheck.
  ///
  /// In en, this message translates to:
  /// **'Test update check'**
  String get devTestUpdateCheck;

  /// No description provided for @devOpenReleases.
  ///
  /// In en, this message translates to:
  /// **'Open the releases page'**
  String get devOpenReleases;

  /// No description provided for @devSectionDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get devSectionDiagnostics;

  /// No description provided for @devCollectDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Collect diagnostics (and copy)'**
  String get devCollectDiagnostics;

  /// No description provided for @devSectionDanger.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get devSectionDanger;

  /// No description provided for @devClearAllPrefs.
  ///
  /// In en, this message translates to:
  /// **'Clear all local settings'**
  String get devClearAllPrefs;

  /// No description provided for @devConfirmClear.
  ///
  /// In en, this message translates to:
  /// **'Clear everything? Sign-in, sync progress and every setting will be reset. This cannot be undone.'**
  String get devConfirmClear;

  /// No description provided for @devCleared.
  ///
  /// In en, this message translates to:
  /// **'All local settings cleared'**
  String get devCleared;

  /// No description provided for @devLockAgain.
  ///
  /// In en, this message translates to:
  /// **'Lock developer options'**
  String get devLockAgain;

  /// No description provided for @devAnnouncementPageDesc.
  ///
  /// In en, this message translates to:
  /// **'Test fetching · test the popup · announcement manager'**
  String get devAnnouncementPageDesc;

  /// No description provided for @devTestPopup.
  ///
  /// In en, this message translates to:
  /// **'Test the announcement popup'**
  String get devTestPopup;

  /// No description provided for @devManager.
  ///
  /// In en, this message translates to:
  /// **'Announcement manager'**
  String get devManager;

  /// No description provided for @devManagerDesc.
  ///
  /// In en, this message translates to:
  /// **'Publish / take down / restore from history'**
  String get devManagerDesc;

  /// No description provided for @devManagerTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage announcements'**
  String get devManagerTitle;

  /// No description provided for @devSectionRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get devSectionRead;

  /// No description provided for @devCurrentContent.
  ///
  /// In en, this message translates to:
  /// **'Current content on GitHub'**
  String get devCurrentContent;

  /// No description provided for @devHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get devHistory;

  /// No description provided for @devHistoryHint.
  ///
  /// In en, this message translates to:
  /// **'A GitHub token is required'**
  String get devHistoryHint;

  /// No description provided for @devLoadIntoForm.
  ///
  /// In en, this message translates to:
  /// **'Load into form'**
  String get devLoadIntoForm;

  /// No description provided for @devRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore this version'**
  String get devRestore;

  /// No description provided for @devManagerNote.
  ///
  /// In en, this message translates to:
  /// **'The token stays on this device; publishing commits docs/announcement.json'**
  String get devManagerNote;

  /// No description provided for @devSectionStartupNotice.
  ///
  /// In en, this message translates to:
  /// **'Startup notice (copyright)'**
  String get devSectionStartupNotice;

  /// No description provided for @devCustomProbe.
  ///
  /// In en, this message translates to:
  /// **'Probe a custom URL'**
  String get devCustomProbe;

  /// No description provided for @devCustomProbeDesc.
  ///
  /// In en, this message translates to:
  /// **'Try candidate mirrors on your own network (statically / githack / self-hosted proxy…) and see whether they are usable and up to date'**
  String get devCustomProbeDesc;

  /// No description provided for @devProbe.
  ///
  /// In en, this message translates to:
  /// **'Probe'**
  String get devProbe;

  /// No description provided for @devFinalChoice.
  ///
  /// In en, this message translates to:
  /// **'Selected source'**
  String get devFinalChoice;

  /// No description provided for @devWinnerTag.
  ///
  /// In en, this message translates to:
  /// **'selected'**
  String get devWinnerTag;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
