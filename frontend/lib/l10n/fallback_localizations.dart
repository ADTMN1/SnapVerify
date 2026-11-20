import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Wraps a delegate so it claims every locale and serves its default English
/// implementation for locales it does not know.
///
/// SnapVerify ships `om` (Afaan Oromoo) strings through the generated
/// `AppLocalizations`, but Flutter's Material/Cupertino delegates have no `om`
/// data. Without this adapter the framework reports
/// "locale om is not supported by all of its localization delegates" in debug
/// builds. Material/Cupertino system widgets fall back to English while
/// `AppLocalizations` keeps serving Amharic/Oromo.
class FallbackLocalizationsDelegate<T> extends LocalizationsDelegate<T> {
  const FallbackLocalizationsDelegate(this._inner);

  final LocalizationsDelegate<T> _inner;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<T> load(Locale locale) => _inner.load(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<T> old) => false;
}

/// Delegates appended after [AppLocalizations.localizationsDelegates].
const fallbackLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  FallbackLocalizationsDelegate<MaterialLocalizations>(
    DefaultMaterialLocalizations.delegate,
  ),
  FallbackLocalizationsDelegate<CupertinoLocalizations>(
    DefaultCupertinoLocalizations.delegate,
  ),
];