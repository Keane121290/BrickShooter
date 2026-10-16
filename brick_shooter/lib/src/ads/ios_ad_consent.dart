import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

typedef AsyncConsentStep = Future<void> Function();
typedef ConsentFlag = Future<bool> Function();

/// iOS-only UMP and ATT gate. Ads cannot initialize until this resolves.
class IosAdConsent extends ChangeNotifier {
  IosAdConsent({
    AsyncConsentStep? updateConsent,
    AsyncConsentStep? showConsentForm,
    AsyncConsentStep? requestTracking,
    ConsentFlag? canRequestAds,
    ConsentFlag? needsPrivacyOptions,
    AsyncConsentStep? showPrivacyOptions,
  }) : _updateConsent = updateConsent ?? _updateUmpConsent,
       _showConsentForm = showConsentForm ?? _showUmpConsentForm,
       _requestTracking = requestTracking ?? _requestAtt,
       _canRequestAds = canRequestAds ?? _canRequestUmpAds,
       _needsPrivacyOptions = needsPrivacyOptions ?? _umpNeedsPrivacyOptions,
       _showPrivacyOptions = showPrivacyOptions ?? _showUmpPrivacyOptions;

  static final IosAdConsent instance = IosAdConsent();
  static const MethodChannel _trackingChannel = MethodChannel(
    'brick_shooter/tracking',
  );

  final AsyncConsentStep _updateConsent;
  final AsyncConsentStep _showConsentForm;
  final AsyncConsentStep _requestTracking;
  final ConsentFlag _canRequestAds;
  final ConsentFlag _needsPrivacyOptions;
  final AsyncConsentStep _showPrivacyOptions;

  Future<bool>? _ready;
  bool _privacyOptionsRequired = false;
  bool _consentUnreachable = false;

  bool get privacyOptionsRequired => _privacyOptionsRequired;

  /// True when ads may load. A failed consent request does not block them,
  /// because the form could not be shown. A completed refusal still does.
  Future<bool> adsAllowed() async {
    if (_consentUnreachable) return true;
    return canRequestAds();
  }

  Future<bool> ensureReady() => _ready ??= _prepare();

  Future<bool> _prepare() async {
    try {
      await _updateConsent();
      await _showConsentForm();
      _consentUnreachable = false;
    } catch (error) {
      _consentUnreachable = true;
      debugPrint('UMP consent update/form failed: $error');
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await _requestTracking();
      } catch (error) {
        debugPrint('ATT request failed: $error');
        return false;
      }
    }

    await _refreshPrivacyOptions();
    if (_consentUnreachable) return true;
    return canRequestAds();
  }

  Future<bool> canRequestAds() async {
    try {
      return await _canRequestAds();
    } catch (error) {
      debugPrint('UMP canRequestAds failed: $error');
      return false;
    }
  }

  Future<bool> showPrivacyOptionsForm() async {
    try {
      await _showPrivacyOptions();
      _ready = null;
      await _refreshPrivacyOptions();
      return true;
    } catch (error) {
      debugPrint('UMP privacy options form failed: $error');
      return false;
    }
  }

  Future<void> _refreshPrivacyOptions() async {
    try {
      final required = await _needsPrivacyOptions();
      if (required != _privacyOptionsRequired) {
        _privacyOptionsRequired = required;
        notifyListeners();
      }
    } catch (error) {
      debugPrint('UMP privacy options check failed: $error');
    }
  }

  static Future<void> _updateUmpConsent() async {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => completer.complete(),
      (error) => completer.completeError(
        StateError('UMP ${error.errorCode}: ${error.message}'),
      ),
    );
    await completer.future;
  }

  static Future<void> _showUmpConsentForm() async {
    final completer = Completer<void>();
    ConsentForm.loadAndShowConsentFormIfRequired((error) {
      if (error == null) {
        completer.complete();
      } else {
        completer.completeError(
          StateError('UMP ${error.errorCode}: ${error.message}'),
        );
      }
    });
    await completer.future;
  }

  static Future<bool> _canRequestUmpAds() {
    return ConsentInformation.instance.canRequestAds();
  }

  static Future<bool> _umpNeedsPrivacyOptions() async {
    final status = await ConsentInformation.instance
        .getPrivacyOptionsRequirementStatus();
    return status == PrivacyOptionsRequirementStatus.required;
  }

  static Future<void> _showUmpPrivacyOptions() async {
    final completer = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((error) {
      if (error == null) {
        completer.complete();
      } else {
        completer.completeError(
          StateError('UMP ${error.errorCode}: ${error.message}'),
        );
      }
    });
    await completer.future;
  }

  static Future<void> _requestAtt() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final status = await _trackingChannel.invokeMethod<int>(
      'requestTrackingAuthorization',
    );
    if (status == null) {
      throw StateError('iOS tracking authorization did not return a status');
    }
  }
}
