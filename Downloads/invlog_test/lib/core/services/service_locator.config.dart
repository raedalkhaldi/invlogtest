// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:cloud_firestore/cloud_firestore.dart' as _i974;
import 'package:firebase_auth/firebase_auth.dart' as _i59;
import 'package:firebase_storage/firebase_storage.dart' as _i457;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:invlog/core/services/service_locator.dart' as _i350;

extension GetItInjectableX on _i174.GetIt {
// initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(
      this,
      environment,
      environmentFilter,
    );
    final serviceLocator = _$ServiceLocator();
    gh.singleton<_i59.FirebaseAuth>(() => serviceLocator.firebaseAuth);
    gh.singleton<_i974.FirebaseFirestore>(() => serviceLocator.firestore);
    gh.singleton<_i457.FirebaseStorage>(() => serviceLocator.storage);
    return this;
  }
}

class _$ServiceLocator extends _i350.ServiceLocator {}
