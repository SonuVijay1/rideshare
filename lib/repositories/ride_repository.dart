// lib/repositories/ride_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_repository.dart';

abstract class RideRepository {
  Future<void> publishRide(String uid, Map<String, dynamic> rideData,
      {String? rideId});
  Future<void> cancelRide(String uid, String rideId, String reason);
  Future<List<Map<String, dynamic>>> searchRides(
      double fromLat, double fromLng, double toLat, double toLng, int seats);
  Stream<List<Map<String, dynamic>>> getDriverTrips(String uid);
  Stream<List<Map<String, dynamic>>> getBookedTrips(String uid);

  // Booking logic
  Future<Map<String, dynamic>?> getBookingForRide(String uid, String rideId);
  Stream<Map<String, dynamic>?> getRideStream(String driverId, String rideId);
  Future<Map<String, dynamic>?> getRide(String driverId, String rideId);
  Future<void> bookRide({
    required String rideId,
    required String driverId,
    required String userId,
    required String userName,
    required String? userPic,
    required int seats,
    required Map<String, dynamic> rideData,
    String? existingBookingId,
    int? existingBookedSeats,
  });
  Future<void> cancelBooking({
    required String rideId,
    required String driverId,
    required String userId,
    required String bookingId,
    required int seatsBooked,
  });
  Future<void> submitReview({
    required String rideId,
    required String reviewerId,
    required String revieweeId,
    required double rating,
    required String comment,
    required bool isDriverReviewing,
  });
  Stream<List<Map<String, dynamic>>> getMessages(String rideId);
  Future<void> sendMessage(
      String rideId, String message, String senderId, String senderName);
  Future<void> setTypingStatus(
      String rideId, String userId, String userName, bool isTyping);
  Stream<List<String>> getTypingUsers(String rideId, String excludeUserId);
}

class FirebaseRideRepository implements RideRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // We use the concrete implementation here to access the rateUser method
  final FirebaseUserRepository _userRepo = FirebaseUserRepository();

  @override
  Future<void> publishRide(String uid, Map<String, dynamic> rideData,
      {String? rideId}) async {
    rideData['driverId'] = uid; // Ensure driverId is in the global doc

    if (rideId != null) {
      await _firestore.collection("rides").doc(rideId).update(rideData);
    } else {
      await _firestore.collection("rides").add(rideData);
    }
  }

  @override
  Future<void> cancelRide(String uid, String rideId, String reason) async {
    final rideRef = _firestore.collection("rides").doc(rideId);
    final docSnap = await rideRef.get();
    if (!docSnap.exists) return;

    final data = docSnap.data()!;
    final batch = _firestore.batch();

    batch.update(rideRef, {
      'status': 'Cancelled',
      'cancellationReason': reason,
      'cancelledAt': FieldValue.serverTimestamp(),
    });

    final bookedUsers =
        List<Map<String, dynamic>>.from(data['bookedUsers'] ?? []);
    for (final user in bookedUsers) {
      final pUid = user['uid'];
      if (pUid != null) {
        final q = await _firestore
            .collection('rideBookings')
            .where('passengerId', isEqualTo: pUid)
            .where('rideId', isEqualTo: rideId)
            .get();
        for (final pDoc in q.docs) {
          batch.update(pDoc.reference, {
            'status': 'Cancelled',
            'cancellationReason': reason,
            'cancelledAt': FieldValue.serverTimestamp(),
          });
          // Notify Passenger
          _sendNotification(
            pUid,
            "Ride Cancelled",
            "The ride you booked has been cancelled by the driver.",
            "cancellation",
            rideId,
          );
        }
      }
    }
    await batch.commit();
  }

  Future<void> _sendNotification(String userId, String title, String body,
      String type, String referenceId) async {
    await _firestore.collection('notifications').add({
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'referenceId': referenceId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<List<Map<String, dynamic>>> searchRides(double fromLat, double fromLng,
      double toLat, double toLng, int seats) async {
    // Note: Complex geo-query logic from BookRideScreen would go here.
    // Querying global 'rides' collection
    final snapshot = await _firestore
        .collection("rides")
        .where("status", isEqualTo: "Upcoming")
        // .where("seatsAvailable", isGreaterThanOrEqualTo: seats) // Optional optimization
        .get();

    // We return the docs with their ID and reference path included for the UI to use
    return snapshot.docs.map((d) {
      final data = d.data();
      data['rideId'] = d.id;
      // driverId is now part of the document data
      return data;
    }).toList();
  }

  @override
  Stream<List<Map<String, dynamic>>> getDriverTrips(String uid) {
    return _firestore
        .collection("rides")
        .where('driverId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final trips = snap.docs.map((d) {
        final data = d.data();
        data['rideId'] = d.id;
        return data;
      }).toList();
      // Sort client-side to avoid composite index requirement
      trips.sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));
      return trips;
    });
  }

  @override
  Stream<List<Map<String, dynamic>>> getBookedTrips(String uid) {
    return _firestore
        .collection("rideBookings")
        .where('passengerId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final trips = snap.docs.map((d) {
        final data = d.data();
        data['bookingId'] = d.id;
        return data;
      }).toList();
      // Sort client-side
      trips.sort((a, b) {
        final tA = a['bookedAt'];
        final tB = b['bookedAt'];
        if (tA is Timestamp && tB is Timestamp) return tB.compareTo(tA);
        return (tB?.toString() ?? '').compareTo(tA?.toString() ?? '');
      });
      return trips;
    });
  }

  @override
  Future<Map<String, dynamic>?> getBookingForRide(
      String uid, String rideId) async {
    final q = await _firestore
        .collection('rideBookings')
        .where('passengerId', isEqualTo: uid)
        .where('rideId', isEqualTo: rideId)
        .limit(1)
        .get();

    if (q.docs.isNotEmpty) {
      final data = q.docs.first.data();
      data['bookingId'] = q.docs.first.id;
      return data;
    }
    return null;
  }

  @override
  Stream<Map<String, dynamic>?> getRideStream(String driverId, String rideId) {
    // driverId is ignored as we use global collection, but kept for interface compatibility
    return _firestore
        .collection('rides')
        .doc(rideId)
        .snapshots()
        .map((doc) => doc.data());
  }

  @override
  Future<Map<String, dynamic>?> getRide(String driverId, String rideId) async {
    final doc = await _firestore.collection('rides').doc(rideId).get();
    return doc.data();
  }

  @override
  Future<void> bookRide({
    required String rideId,
    required String driverId,
    required String userId,
    required String userName,
    required String? userPic,
    required int seats,
    required Map<String, dynamic> rideData,
    String? existingBookingId,
    int? existingBookedSeats,
  }) async {
    final rideRef = _firestore.collection('rides').doc(rideId);
    final isUpdate = existingBookingId != null;

    await _firestore.runTransaction((transaction) async {
      final rideSnapshot = await transaction.get(rideRef);
      if (!rideSnapshot.exists) throw Exception("Ride does not exist");

      final snapshotData = rideSnapshot.data()!;
      final currentSeats = snapshotData['seatsAvailable'] as int;

      int seatsChange = seats;
      if (isUpdate) {
        seatsChange = seats - existingBookedSeats!;
      }

      if (seatsChange > 0 && currentSeats < seatsChange) {
        throw Exception("Not enough seats available");
      }

      List<dynamic> bookedUsers = List.from(snapshotData['bookedUsers'] ?? []);
      if (isUpdate) {
        bookedUsers.removeWhere((element) => element['uid'] == userId);
      }

      bookedUsers.add({
        'uid': userId,
        'name': userName,
        'profilePic': userPic,
        'seats': seats,
        'bookedAt': DateTime.now().toString()
      });

      transaction.update(rideRef, {
        'seatsAvailable': currentSeats - seatsChange,
        'seatsBooked': FieldValue.increment(seatsChange),
        'bookedUsers': bookedUsers
      });

      DocumentReference myBookingRef;
      if (isUpdate) {
        myBookingRef =
            _firestore.collection('rideBookings').doc(existingBookingId);
        transaction.update(myBookingRef, {
          'seatsBooked': seats,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        myBookingRef = _firestore.collection('rideBookings').doc();
        final bookingData = Map<String, dynamic>.from(rideData);
        bookingData['seatsBooked'] = seats;
        bookingData['passengerId'] = userId; // New schema field

        // Check booking mode
        final mode = rideData['bookingMode'] ?? 'instant';
        bookingData['status'] = mode == 'instant' ? 'Confirmed' : 'Pending';

        bookingData['bookedAt'] = FieldValue.serverTimestamp();
        bookingData['driverId'] = driverId;
        bookingData['rideId'] = rideId;
        transaction.set(myBookingRef, bookingData);
      }
    }).then((_) {
      // Send notification to driver
      _sendNotification(
          driverId,
          "New Booking",
          "$userName has booked $seats seat(s) on your ride.",
          "booking",
          rideId);
    });
  }

  @override
  Future<void> cancelBooking({
    required String rideId,
    required String driverId,
    required String userId,
    required String bookingId,
    required int seatsBooked,
  }) async {
    final rideRef = _firestore.collection('rides').doc(rideId);
    final userBookingRef = _firestore.collection('rideBookings').doc(bookingId);

    await _firestore.runTransaction((transaction) async {
      final rideSnapshot = await transaction.get(rideRef);
      if (!rideSnapshot.exists) throw Exception("Ride does not exist anymore.");

      final snapshotData = rideSnapshot.data()!;
      List<dynamic> bookedUsers = List.from(snapshotData['bookedUsers'] ?? []);
      final userBookingData =
          bookedUsers.firstWhere((b) => b['uid'] == userId, orElse: () => null);

      if (userBookingData != null) {
        transaction.update(rideRef, {
          'seatsAvailable': FieldValue.increment(seatsBooked),
          'seatsBooked': FieldValue.increment(-seatsBooked),
          'bookedUsers': FieldValue.arrayRemove([userBookingData])
        });
      }
      transaction.delete(userBookingRef);
    });

    // Notify Driver
    _sendNotification(driverId, "Booking Cancelled",
        "A passenger has cancelled their booking.", "cancellation", rideId);
  }

  @override
  Future<void> submitReview({
    required String rideId,
    required String reviewerId,
    required String revieweeId,
    required double rating,
    required String comment,
    required bool isDriverReviewing,
  }) async {
    // 1. Add Review Document
    await _firestore.collection('reviews').add({
      'rideId': rideId,
      'reviewerId': reviewerId,
      'revieweeId': revieweeId,
      'rating': rating,
      'comment': comment,
      'role': isDriverReviewing ? 'driver' : 'passenger',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Update User Rating
    // If driver is reviewing, they are rating a passenger (asDriver=false for the target)
    // If passenger is reviewing, they are rating a driver (asDriver=true for the target)
    await _userRepo.rateUser(revieweeId, rating, !isDriverReviewing);
  }

  @override
  Stream<List<Map<String, dynamic>>> getMessages(String rideId) {
    return _firestore
        .collection('rides')
        .doc(rideId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((query) => query.docs.map((doc) => doc.data()).toList());
  }

  @override
  Future<void> sendMessage(
      String rideId, String message, String senderId, String senderName) async {
    // 1. Add to subcollection
    await _firestore
        .collection('rides')
        .doc(rideId)
        .collection('messages')
        .add({
      'text': message,
      'senderId': senderId,
      'senderName': senderName,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Update metadata for list views (Ride & Bookings)
    final updateData = {
      'lastMessage': message,
      'lastMessageTime': FieldValue.serverTimestamp(),
    };

    // Update Ride (for Driver)
    await _firestore.collection('rides').doc(rideId).update(updateData);

    // Update Bookings (for Passengers)
    final bookings = await _firestore
        .collection('rideBookings')
        .where('rideId', isEqualTo: rideId)
        .get();

    final batch = _firestore.batch();
    for (final doc in bookings.docs) {
      batch.update(doc.reference, updateData);
    }
    await batch.commit();
  }

  @override
  Future<void> setTypingStatus(
      String rideId, String userId, String userName, bool isTyping) async {
    await _firestore
        .collection('rides')
        .doc(rideId)
        .collection('typing')
        .doc(userId)
        .set({
      'isTyping': isTyping,
      'name': userName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<List<String>> getTypingUsers(String rideId, String excludeUserId) {
    return _firestore
        .collection('rides')
        .doc(rideId)
        .collection('typing')
        .where('isTyping', isEqualTo: true)
        .snapshots()
        .map((snap) {
      return snap.docs
          .where((doc) => doc.id != excludeUserId)
          .map((doc) => doc.data()['name'] as String? ?? 'Someone')
          .toList();
    });
  }
}
