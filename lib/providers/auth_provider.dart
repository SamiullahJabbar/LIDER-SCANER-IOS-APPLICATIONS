import 'package:flutter/foundation.dart';
import '../services/local_scan_storage_service.dart';

enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  loading,
}

// ============================================================================
// Production-ready Auth Provider — Fully local SQLite auth
// NO backend API — all auth is on-device with hashed passwords
//
// Fixed bugs:
//   • catch(e) instead of on Exception — catches ALL errors
//   • _initFuture prevents double-init race condition
//   • finally{} blocks guarantee loading state is always cleared
// ============================================================================
class AuthProvider with ChangeNotifier {
  final LocalScanStorageService _storage = LocalScanStorageService.instance;

  AuthStatus _status = AuthStatus.initial;
  int? _userId;
  String? _userName;
  String? _userEmail;
  String? _firstName;
  String? _lastName;
  String? _errorMessage;
  bool _isLoading = false;

  // Prevent double-initialization race
  Future<void>? _initFuture;
  bool _initialized = false;

  // ── Getters ──────────────────────────────────────────────────────────────

  AuthStatus get status => _status;
  int? get userId => _userId;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get firstName => _firstName;
  String? get lastName => _lastName;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  // ── Initialize ───────────────────────────────────────────────────────────

  /// Initialize auth state from local storage (session persistence).
  /// Safe to call multiple times — only runs once.
  Future<void> initialize() {
    _initFuture ??= _doInitialize();
    return _initFuture!;
  }

  Future<void> _doInitialize() async {
    if (_initialized) return;

    try {
      _status = AuthStatus.loading;
      notifyListeners();

      final savedUserId = await _storage.getSetting('current_user_id');
      final isLoggedIn = await _storage.getSetting('is_logged_in');

      if (isLoggedIn == 'true' &&
          savedUserId != null &&
          savedUserId.isNotEmpty) {
        final id = int.tryParse(savedUserId);
        if (id != null) {
          final user = await _storage.getUserById(id);
          if (user != null) {
            _userId = id;
            _userName = user['username'] as String?;
            _userEmail = user['email'] as String?;
            _firstName = user['firstName'] as String?;
            _lastName = user['lastName'] as String?;
            _status = AuthStatus.authenticated;
            _initialized = true;
            _isLoading = false;
            notifyListeners();
            debugPrint('✅ Auth restored session: $_userEmail (id=$_userId)');
            return;
          }
        }
      }

      _status = AuthStatus.unauthenticated;
    } catch (e) {
      debugPrint('⚠️ Auth init error: $e');
      _status = AuthStatus.unauthenticated;
    } finally {
      _initialized = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Register ─────────────────────────────────────────────────────────────

  /// Register a new user — stores in SQLite users table with hashed password.
  /// Returns true on success, false on failure (check [errorMessage]).
  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? companyName,
    String? jobTitle,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // ── Validation ──
      if (username.trim().isEmpty ||
          email.trim().isEmpty ||
          password.isEmpty) {
        _errorMessage = 'Username, email, and password are required';
        return false;
      }

      if (password != passwordConfirm) {
        _errorMessage = 'Passwords do not match';
        return false;
      }

      if (password.length < 6) {
        _errorMessage = 'Password must be at least 6 characters';
        return false;
      }

      if (!_isValidEmail(email)) {
        _errorMessage = 'Please enter a valid email address';
        return false;
      }

      // ── Insert into SQLite ──
      final userId = await _storage.registerUser(
        username: username,
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        companyName: companyName,
        jobTitle: jobTitle,
      );

      // ── Auto-login after registration ──
      _userId = userId;
      _userName = username.trim();
      _userEmail = email.toLowerCase().trim();
      _firstName = firstName?.trim();
      _lastName = lastName?.trim();
      _status = AuthStatus.authenticated;

      // ── Persist session ──
      await _storage.saveSetting('current_user_id', userId.toString());
      await _storage.saveSetting('is_logged_in', 'true');

      debugPrint('✅ Registration successful: $username (id=$userId)');
      return true;
    } catch (e) {
      // Catches BOTH Exception AND Error — prevents stuck loading
      final msg = e.toString();
      if (msg.contains('email already exists')) {
        _errorMessage = 'An account with this email already exists';
      } else if (msg.contains('username is already taken')) {
        _errorMessage = 'This username is already taken';
      } else {
        _errorMessage =
            'Registration failed: ${msg.replaceFirst('Exception: ', '')}';
      }
      debugPrint('❌ Registration error: $_errorMessage');
      return false;
    } finally {
      // ALWAYS clear loading — even if error is thrown
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Login ────────────────────────────────────────────────────────────────

  /// Login — validates email + password against SQLite users table.
  /// Returns true on success, false on failure (check [errorMessage]).
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (email.trim().isEmpty || password.isEmpty) {
        _errorMessage = 'Email and password are required';
        return false;
      }

      // ── Authenticate against SQLite ──
      final user = await _storage.authenticateUser(
        email: email,
        password: password,
      );

      if (user == null) {
        _errorMessage = 'Invalid email or password';
        return false;
      }

      // ── Set session ──
      _userId = user['id'] as int;
      _userName = user['username'] as String?;
      _userEmail = user['email'] as String?;
      _firstName = user['firstName'] as String?;
      _lastName = user['lastName'] as String?;
      _status = AuthStatus.authenticated;

      // ── Persist session ──
      await _storage.saveSetting('current_user_id', _userId.toString());
      await _storage.saveSetting('is_logged_in', 'true');

      debugPrint('✅ Login successful: $_userEmail (id=$_userId)');
      return true;
    } catch (e) {
      _errorMessage = 'Login failed. Please try again.';
      debugPrint('❌ Login error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Logout ───────────────────────────────────────────────────────────────

  /// Logout — clears session from SQLite settings
  Future<void> logout() async {
    try {
      await _storage.saveSetting('is_logged_in', 'false');
      await _storage.saveSetting('current_user_id', '');
    } catch (e) {
      debugPrint('Logout error: $e');
    } finally {
      _userId = null;
      _userName = null;
      _userEmail = null;
      _firstName = null;
      _lastName = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Profile Update ───────────────────────────────────────────────────────

  /// Update profile locally in SQLite
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_userId == null) {
        _errorMessage = 'No user logged in';
        return false;
      }

      await _storage.updateUser(_userId!, data);

      if (data.containsKey('username')) _userName = data['username'];
      if (data.containsKey('email')) _userEmail = data['email'];
      if (data.containsKey('firstName')) _firstName = data['firstName'];
      if (data.containsKey('lastName')) _lastName = data['lastName'];

      return true;
    } catch (e) {
      _errorMessage = 'Failed to update profile.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Change Password ──────────────────────────────────────────────────────

  /// Change password — validates old password first
  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
    required String newPasswordConfirm,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_userId == null) {
        _errorMessage = 'No user logged in';
        return false;
      }

      if (newPassword != newPasswordConfirm) {
        _errorMessage = 'New passwords do not match';
        return false;
      }

      if (newPassword.length < 6) {
        _errorMessage = 'Password must be at least 6 characters';
        return false;
      }

      final success = await _storage.changeUserPassword(
        userId: _userId!,
        oldPassword: oldPassword,
        newPassword: newPassword,
      );

      if (!success) {
        _errorMessage = 'Current password is incorrect';
        return false;
      }

      return true;
    } catch (e) {
      _errorMessage = 'Failed to change password.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Password Reset ───────────────────────────────────────────────────────

  /// Password reset — not available in offline mode
  Future<bool> requestPasswordReset(String email) async {
    _errorMessage = 'Password reset is not available in offline mode.';
    notifyListeners();
    return false;
  }

  // ── Profile Picture ──────────────────────────────────────────────────────

  /// Save profile picture path locally
  Future<bool> uploadProfilePicture(String filePath) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_userId == null) {
        _errorMessage = 'No user logged in';
        return false;
      }

      await _storage.updateUser(_userId!, {'profilePicturePath': filePath});
      return true;
    } catch (e) {
      _errorMessage = 'Failed to save profile picture.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Delete Account ───────────────────────────────────────────────────────

  /// Delete account — verifies password before deletion
  Future<bool> deleteAccount(String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_userId == null || _userEmail == null) {
        _errorMessage = 'No user logged in';
        return false;
      }

      // Verify password before deletion
      final user = await _storage.authenticateUser(
        email: _userEmail!,
        password: password,
      );

      if (user == null) {
        _errorMessage = 'Incorrect password';
        return false;
      }

      await _storage.deleteUser(_userId!);
      await _storage.saveSetting('is_logged_in', 'false');
      await _storage.saveSetting('current_user_id', '');

      _userId = null;
      _userName = null;
      _userEmail = null;
      _firstName = null;
      _lastName = null;
      _status = AuthStatus.unauthenticated;

      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete account.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Email validation
  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email.trim());
  }
}
