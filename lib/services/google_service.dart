import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:http/http.dart' as http;
import 'package:googleapis/calendar/v3.dart' as calendar;

/// A small authenticated http client that replays the auth headers provided
/// by `GoogleSignInAccount.authHeaders`.
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner;
  GoogleAuthClient(this._headers, [http.Client? inner]) : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}

class GoogleService {
  GoogleService._internal();
  static final GoogleService instance = GoogleService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      calendar.CalendarApi.calendarReadonlyScope,
      'email',
      'profile',
    ],
  );

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Future<GoogleSignInAccount?> signIn() async {
    try {
      final acct = await _googleSignIn.signIn();
      if (acct == null) return null;
      // Sign in to Firebase using the Google credentials so the app can leverage
      // Firebase-authenticated features if desired.
      try {
        final auth = await acct.authentication;
        final credential = fb_auth.GoogleAuthProvider.credential(
          accessToken: auth.accessToken,
          idToken: auth.idToken,
        );
        await fb_auth.FirebaseAuth.instance.signInWithCredential(credential);
      } catch (_) {}

      return acct;
    } catch (e) {
      // return null on errors
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }
  }

  Future<http.Client?> _authedClient() async {
    final acct = _googleSignIn.currentUser;
    if (acct == null) return null;
    final headers = await acct.authHeaders;
    return GoogleAuthClient(headers);
  }

  /// List calendars visible to the signed-in user.
  Future<List<calendar.CalendarListEntry>> listCalendars() async {
    final client = await _authedClient();
    if (client == null) return [];
    final api = calendar.CalendarApi(client);
    try {
      final list = await api.calendarList.list();
      return list.items ?? [];
    } catch (_) {
      return [];
    }
  }

  /// Fetch events from a calendar id between [from] and [to]. Returns empty
  /// list on error or when not signed in.
  Future<List<calendar.Event>> fetchCalendarEvents(String calendarId, DateTime from, DateTime to) async {
    final client = await _authedClient();
    if (client == null) return [];
    final api = calendar.CalendarApi(client);
    try {
      final res = await api.events.list(
        calendarId,
        timeMin: from.toUtc(),
        timeMax: to.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
        maxResults: 2500,
      );
      return res.items ?? [];
    } catch (_) {
      return [];
    }
  }

  /// Convenience: fetch events from the primary calendar.
  Future<List<calendar.Event>> fetchPrimaryEvents(DateTime from, DateTime to) async {
    return fetchCalendarEvents('primary', from, to);
  }

  /// Helper to fetch a known public holiday calendar if the caller provides the
  /// calendar id (for example: 'en.usa#holiday@group.v.calendar.google.com').
  Future<List<calendar.Event>> fetchHolidaysCalendar(String holidayCalendarId, DateTime from, DateTime to) async {
    return fetchCalendarEvents(holidayCalendarId, from, to);
  }

  /// Fetch events from [calendarId] and return a map of dateKey (yyyy-MM-dd)
  /// -> list of events that occur on that date. This normalizes all-day
  /// events (Event.start.date) and timed events (Event.start.dateTime) and
  /// expands multi-day events into each date they cover.
  Future<Map<String, List<calendar.Event>>> fetchHolidayEventsByDate(String calendarId, DateTime from, DateTime to) async {
    final client = await _authedClient();
    if (client == null) return {};
    final api = calendar.CalendarApi(client);
    String? pageToken;
    final map = <String, List<calendar.Event>>{};
    do {
      final res = await api.events.list(
        calendarId,
        timeMin: from.toUtc(),
        timeMax: to.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
        maxResults: 2500,
        pageToken: pageToken,
      );

      final items = res.items ?? [];
      for (final evt in items) {
        DateTime? startDate;
        DateTime? endDate;
        final s = evt.start;
        final e = evt.end;

        // Handle all-day events where start.date is provided (often a String)
        if (s?.date != null) {
          dynamic raw = s!.date;
          if (raw is String) startDate = DateTime.tryParse(raw);
          else if (raw is DateTime) startDate = raw;

          dynamic rawEnd = e?.date;
          if (rawEnd != null) {
            if (rawEnd is String) endDate = DateTime.tryParse(rawEnd);
            else if (rawEnd is DateTime) endDate = rawEnd;
          } else {
            endDate = startDate?.add(const Duration(days: 1));
          }
        } else if (s?.dateTime != null) {
          // Timed event
          startDate = s!.dateTime;
          endDate = e?.dateTime ?? startDate?.add(const Duration(days: 1));
        }

        if (startDate == null || endDate == null) continue;

        // Normalize to local dates and expand multi-day ranges
        DateTime d = DateTime(startDate.year, startDate.month, startDate.day);
        final last = DateTime(endDate.year, endDate.month, endDate.day).subtract(const Duration(days: 1));
        while (!d.isAfter(last)) {
          final key = d.toIso8601String().split('T').first;
          map.putIfAbsent(key, () => []).add(evt);
          d = d.add(const Duration(days: 1));
        }
      }

      pageToken = res.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);

    return map;
  }
}
