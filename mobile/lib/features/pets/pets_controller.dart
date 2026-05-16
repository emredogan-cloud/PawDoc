/// Pets data store — reads + writes the public.pets table under the user
/// JWT. RLS guarantees the user only sees their own rows.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../shared/models/pet.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/services/logger.dart';
import '../../shared/services/supabase_client.dart';

@immutable
sealed class PetsState {
  const PetsState();
}

class PetsLoading extends PetsState {
  const PetsLoading();
}

class PetsReady extends PetsState {
  const PetsReady(this.pets);
  final List<Pet> pets;

  bool get isEmpty => pets.isEmpty;
}

class PetsError extends PetsState {
  const PetsError(this.message);
  final String message;
}

class PetsController extends StateNotifier<PetsState> {
  PetsController(this._client, this._authStatus) : super(const PetsLoading()) {
    _refresh();
  }

  final SupabaseClient _client;
  final AuthStatus _authStatus;
  static final _log = AppLogger.of('pets.controller');

  Future<void> _refresh() async {
    final auth = _authStatus;
    if (auth is! Authenticated) {
      state = const PetsReady([]);
      return;
    }
    state = const PetsLoading();
    try {
      final rows = await _client
          .from('pets')
          .select()
          .eq('user_id', auth.user.id)
          .eq('is_active', true)
          .order('created_at');
      final pets = rows.map((j) => Pet.fromJson(j)).toList(growable: false);
      state = PetsReady(pets);
      _log.info('pets_loaded', pets.length);
    } on PostgrestException catch (e) {
      _log.warning('pets_load_failed', e.message);
      state = const PetsError('Could not load your pets. Pull down to retry.');
    } on Object catch (e, s) {
      _log.severe('pets_load_unexpected', e, s);
      state = const PetsError('Something went wrong loading pets.');
    }
  }

  Future<void> refresh() => _refresh();

  /// Insert a new pet row. Returns the created [Pet], or throws a friendly
  /// error message. The caller (the onboarding screen) renders the
  /// thrown message inline.
  Future<Pet> create(PetCreate input) async {
    try {
      final row = await _client
          .from('pets')
          .insert(input.toJson())
          .select()
          .single();
      final pet = Pet.fromJson(row);
      _log.info('pet_created', pet.id);
      // Optimistically update local state — saves a round trip back.
      final current = state;
      final next = <Pet>[if (current is PetsReady) ...current.pets, pet];
      state = PetsReady(next);
      return pet;
    } on PostgrestException catch (e) {
      _log.warning('pet_create_failed', '${e.code} ${e.message}');
      throw PetCreateFailure(_friendly(e));
    } on Object catch (e, s) {
      _log.severe('pet_create_unexpected', e, s);
      throw const PetCreateFailure("Couldn't save your pet. Try again.");
    }
  }

  String _friendly(PostgrestException e) {
    final raw = e.message.toLowerCase();
    if (raw.contains('check') && raw.contains('species')) {
      return 'That species is not supported yet.';
    }
    if (raw.contains('check') && raw.contains('weight')) {
      return 'Weight must be a positive number.';
    }
    if (raw.contains('not_null') || raw.contains('not-null')) {
      return 'Please fill in all required fields.';
    }
    return "Couldn't save your pet. Try again.";
  }
}

/// Exposed for the onboarding screen to catch + render.
class PetCreateFailure implements Exception {
  const PetCreateFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

final petsControllerProvider = StateNotifierProvider<PetsController, PetsState>(
  (ref) {
    // Re-listen on auth changes so signing out clears the cache.
    ref.listen(authStateProvider, (_, _) {
      // The provider gets re-built; nothing else to do.
    });
    return PetsController(
      ref.watch(supabaseClientProvider),
      ref.watch(authStateProvider),
    );
  },
);
