import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/family.dart';
import '../models/family_member.dart';
import '../repositories/family_repository.dart';
import '../services/api_client.dart';
import '../services/connectivity_service.dart';
import 'auth_provider.dart';

class FamilyState {
  final List<Family> families;
  final Family? currentFamily;
  final List<FamilyMember> members;
  final bool isLoading;

  FamilyState({
    this.families = const [],
    this.currentFamily,
    this.members = const [],
    this.isLoading = false,
  });
}

class FamilyNotifier extends Notifier<FamilyState> {
  final FamilyRepository _repo = FamilyRepository();
  final ApiClient _apiClient = ApiClient();

  @override
  FamilyState build() {
    loadFamilies();
    return FamilyState(isLoading: true);
  }

  Future<void> loadFamilies() async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      state = FamilyState();
      return;
    }

    state = FamilyState(isLoading: true);
    final families = await _repo.getFamiliesForUser(user.id);
    final currentFamily = families.isNotEmpty ? families.first : null;

    List<FamilyMember> members = [];
    if (currentFamily != null) {
      members = await _repo.getMembers(currentFamily.id);
    }

    state = FamilyState(
      families: families,
      currentFamily: currentFamily,
      members: members,
    );
  }

  Future<void> selectFamily(Family family) async {
    final members = await _repo.getMembers(family.id);
    state = FamilyState(
      families: state.families,
      currentFamily: family,
      members: members,
    );
  }

  Future<void> createFamily(String name) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final id = const Uuid().v4();
    final family = Family(id: id, name: name, createdBy: user.id);
    await _repo.insertFamily(family);

    final member = FamilyMember(
      id: const Uuid().v4(),
      familyId: id,
      userId: user.id,
      role: 'admin',
    );
    await _repo.insertMember(member);

    if (ConnectivityService().isOnline) {
      try {
        await _apiClient.dio.post('/families', data: {'id': id, 'name': name});
      } catch (_) {}
    }

    await loadFamilies();
  }

  Future<void> loadMembers() async {
    if (state.currentFamily == null) return;
    final members = await _repo.getMembers(state.currentFamily!.id);
    state = FamilyState(
      families: state.families,
      currentFamily: state.currentFamily,
      members: members,
    );
  }
}

final familyProvider = NotifierProvider<FamilyNotifier, FamilyState>(FamilyNotifier.new);
