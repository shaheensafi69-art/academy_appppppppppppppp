import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/widgets/auth_required_modal.dart';
import '../../../core/widgets/fast_cached_image.dart';
import '../screens/create_story_screen.dart';
import '../screens/story_viewer_screen.dart';
import '../screens/sponsored_story_screen.dart';

class ActiveFriendStory {
  final String userId;
  final String userName;
  final String userAvatar;
  final int storiesCount;

  const ActiveFriendStory({
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.storiesCount,
  });
}

/// Modular horizontal stories tray for Feed.
class FeedStoriesTray extends StatelessWidget {
  final List<ActiveFriendStory> activeFriendStories;
  final VoidCallback onStoryCreated;

  static const Color primaryPink = Color(0xFFF494AC);
  static const Color surfaceWhite = Colors.white;
  static const Color textDark = Color(0xFF111827);

  const FeedStoriesTray({
    super.key,
    required this.activeFriendStories,
    required this.onStoryCreated,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 105,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // دکمه افزودن استوری
          GestureDetector(
            onTap: () {
              final user = Supabase.instance.client.auth.currentUser;
              if (user == null) {
                AuthRequiredModal.show(context, actionName: "create stories");
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateStoryScreen()),
              ).then((_) => onStoryCreated());
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF4F6),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: primaryPink.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          color: primaryPink,
                          size: 22,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: primaryPink,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Add Story",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: textDark,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // استوری اسپانسری
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SponsoredStoryScreen(),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.black,
                      child: Icon(
                        Icons.campaign_rounded,
                        color: Colors.amber,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Sponsored",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // استوری‌های دوستان فعال
          ...activeFriendStories.map((story) {
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StoryViewerScreen(
                      userId: story.userId,
                      userName: story.userName,
                      userAvatar: story.userAvatar,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryPink, Color(0xFFFF4081)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: FastCircleAvatar(
                        imageUrl: story.userAvatar,
                        radius: 20,
                        fallbackText: story.userName.isNotEmpty
                            ? story.userName[0]
                            : 'U',
                        backgroundColor: surfaceWhite,
                        textColor: primaryPink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 58,
                      child: Text(
                        story.userName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
