import 'package:charmi_insta_freelancing/core/error/failure.dart';
import 'package:charmi_insta_freelancing/core/network/api_response.dart';
import 'package:charmi_insta_freelancing/core/utils/result.dart';
import 'package:charmi_insta_freelancing/features/offers/data/datasources/offers_remote_data_source.dart';
import 'package:charmi_insta_freelancing/features/offers/domain/entities/offer.dart';
import 'package:charmi_insta_freelancing/features/offers/domain/repositories/offers_repository.dart';
import 'package:charmi_insta_freelancing/features/offers/presentation/cubit/make_offer_cubit.dart';
import 'package:charmi_insta_freelancing/features/offers/presentation/cubit/offers_list_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockOffersRepo extends Mock implements OffersRepository {}

Offer _offer(int id, {bool received = true}) => Offer(
      id: id,
      loadId: 1,
      priceFormatted: '15,000.00',
      otherPartyName: 'Bob',
      conversationId: 12,
      isReceived: received,
    );

PaginatedResponse<Offer> _page(List<Offer> items, {bool more = false}) =>
    PaginatedResponse(
      items: items,
      meta: PaginationMeta(currentPage: 1, lastPage: more ? 5 : 1),
    );

void main() {
  group('Offer.fromJson', () {
    final json = {
      'id': 1,
      'load_id': 7,
      'body': 'I can take this',
      'price': '15000.00',
      'price_formatted': '15,000.00',
      'conversation_id': 12,
      'user': {'id': 3, 'name': 'Bob User', 'avatar_url': '/b.jpg'},
      'load': {
        'id': 7,
        'title': 'Need flatbed',
        'author': {'id': 2, 'name': 'Alice User', 'avatar_url': null},
      },
      'created_at': '2026-08-25T08:00:00+00:00',
    };

    test('received offer shows the offering user', () {
      final o = Offer.fromJson({...json, 'is_received': true});
      expect(o.isReceived, isTrue);
      expect(o.otherPartyName, 'Bob User');
      expect(o.otherPartyAvatar, '/b.jpg');
      expect(o.priceFormatted, '15,000.00');
      expect(o.loadTitle, 'Need flatbed');
      expect(o.conversationId, 12);
    });

    test('sent offer shows the load author', () {
      final o = Offer.fromJson({...json, 'is_received': false});
      expect(o.otherPartyName, 'Alice User');
    });
  });

  group('OffersListCubit', () {
    late _MockOffersRepo repo;
    setUp(() => repo = _MockOffersRepo());

    test('load populates received offers', () async {
      when(() => repo.getOffers(tag: OfferTag.received, page: 1))
          .thenAnswer((_) async => Success(_page([_offer(1), _offer(2)])));
      final cubit = OffersListCubit(repo);
      await cubit.load();
      expect(cubit.state.status, OffersStatus.loaded);
      expect(cubit.state.offers.length, 2);
    });

    test('setTab switches to sent and reloads', () async {
      when(() => repo.getOffers(tag: OfferTag.received, page: 1))
          .thenAnswer((_) async => Success(_page([_offer(1)])));
      when(() => repo.getOffers(tag: OfferTag.sent, page: 1))
          .thenAnswer((_) async => Success(_page([_offer(9, received: false)])));
      final cubit = OffersListCubit(repo);
      await cubit.load();
      await cubit.setTab(OfferTag.sent);
      expect(cubit.state.tag, OfferTag.sent);
      expect(cubit.state.offers.single.id, 9);
    });

    test('empty result → empty status', () async {
      when(() => repo.getOffers(tag: OfferTag.received, page: 1))
          .thenAnswer((_) async => Success(_page([])));
      final cubit = OffersListCubit(repo);
      await cubit.load();
      expect(cubit.state.status, OffersStatus.empty);
    });

    test('loadMore appends the next page', () async {
      when(() => repo.getOffers(tag: OfferTag.received, page: 1))
          .thenAnswer((_) async => Success(_page([_offer(1)], more: true)));
      when(() => repo.getOffers(tag: OfferTag.received, page: 2))
          .thenAnswer((_) async => Success(_page([_offer(2)])));
      final cubit = OffersListCubit(repo);
      await cubit.load();
      await cubit.loadMore();
      expect(cubit.state.offers.map((o) => o.id), [1, 2]);
    });
  });

  group('MakeOfferCubit', () {
    late _MockOffersRepo repo;
    setUp(() => repo = _MockOffersRepo());

    test('canSubmit needs both price and remarks', () {
      final cubit = MakeOfferCubit(repo, 1);
      expect(cubit.state.canSubmit, isFalse);
      cubit.setPrice('15000');
      expect(cubit.state.canSubmit, isFalse);
      cubit.setRemarks('can do');
      expect(cubit.state.canSubmit, isTrue);
    });

    test('non-numeric price fails validation without calling the API', () async {
      final cubit = MakeOfferCubit(repo, 1);
      cubit.setPrice('abc');
      cubit.setRemarks('note');
      await cubit.submit();
      expect(cubit.state.status, MakeOfferStatus.failure);
      verifyNever(() => repo.makeOffer(
          loadId: any(named: 'loadId'),
          body: any(named: 'body'),
          price: any(named: 'price')));
    });

    test('success emits the created offer', () async {
      when(() => repo.makeOffer(loadId: 1, body: 'note', price: 15000))
          .thenAnswer((_) async => Success(_offer(5)));
      final cubit = MakeOfferCubit(repo, 1);
      cubit.setPrice(' 15000 ');
      cubit.setRemarks(' note ');
      await cubit.submit();
      expect(cubit.state.status, MakeOfferStatus.success);
      expect(cubit.state.created?.id, 5);
    });

    test('409/failure surfaces the server message', () async {
      when(() => repo.makeOffer(loadId: 1, body: 'note', price: 15000))
          .thenAnswer((_) async =>
              const Err(ServerFailure('You already made an offer')));
      final cubit = MakeOfferCubit(repo, 1);
      cubit.setPrice('15000');
      cubit.setRemarks('note');
      await cubit.submit();
      expect(cubit.state.status, MakeOfferStatus.failure);
      expect(cubit.state.errorMessage, 'You already made an offer');
    });
  });
}
