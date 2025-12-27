import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../models/game_types.dart';
import '../utils/localization.dart';
import '../widgets/game_components.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  // --- OYUN DEĞİŞKENLERİ ---
  bool isPlaying = false;
  int score = 0;
  int level = 1;
  double progress = 1.0;
  Timer? _gameTimer;
  Timer? _waitTaskTimer;
  int speedMilliseconds = 3000;
  
  // --- GÜNLÜK TEST ---
  String? lastDailyTestDate;
  bool isDailyTestActive = false;

  // --- BEYİN METRİKLERİ ---
  double brainStability = 50.0;
  Map<String, double> brainSections = {
    "Refleks": 10.0,
    "Algı": 10.0,
    "Mantık": 10.0,
    "Duygu": 10.0,
    "Kontrol": 10.0,
  };
  
  // --- REKLAM ---
  BannerAd? _bannerAd;
  bool _isBannerReady = false;
  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;
  int deathCount = 0;

  final String _bannerUnitId = 'ca-app-pub-3940256099942544/6300978111';
  final String _rewardedUnitId = 'ca-app-pub-3940256099942544/5224354917';
  final String _interstitialUnitId = 'ca-app-pub-3940256099942544/1033173712';

  // --- SES & AYARLAR ---
  DateTime _taskStartTime = DateTime.now();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _musicPlayer = AudioPlayer();
  String? currentMusicTrack;
  double soundVolume = 1.0;
  double musicVolume = 0.5;
  String language = "TR";

  int speedComboCount = 0;
  bool isFeverMode = false;
  
  int nextMotivationTarget = 0;
  String currentMotivationText = "";
  bool showMotivation = false;

  // --- BUFFLAR (GÜÇLENDİRMELER) ---
  bool activeSecondChance = false;
  bool activeTimeSlow = false;
  bool activeDoubleCandy = false;
  bool activeTripleCandy = false; 
  
  // Mod Buffları
  bool activeReflexOnly = false;
  bool activeMathOnly = false;
  bool activeColorOnly = false;
  bool activeEmojiOnly = false;

  int totalCandy = 1000;
  int earnedCandyThisRound = 0;

  Map<String, int> inventory = {
    "heart": 0,
    "time_potion": 0,
    "sugar_potion": 0,
    "sugar_x3": 0,
    "reflex_serum": 0,
    "math_serum": 0,
    "color_serum": 0,
    "emoji_serum": 0,
  };

  TaskType currentTask = TaskType.direction;
  Direction currentDirection = Direction.up;
  bool isReverseRound = true;
  String colorText = "MAVİ";
  Color colorInk = Colors.red;
  Color correctColor = Colors.blue;
  String colorInstruction = "";
  List<Color> colorOptions = [];
  String mathEquation = "";
  bool isMathCorrect = false;
  String emojiText = "";
  String correctEmoji = "";
  List<String> emojiOptions = [];

  bool isGiftVisible = false;
  double giftTopPosition = 0;
  double giftLeftPosition = 0;
  Timer? _giftSpawnTimer;
  String giftBonusText = "";
  bool isBonusTextVisible = false;

  final Color primaryPink = const Color(0xFFFF69B4);
  final Color accentCyan = const Color(0xFF00E5FF);
  final Color bgNormal1 = const Color(0xFFFF9A9E);
  final Color bgNormal2 = const Color(0xFFFECFEF);
  final Color bgFever1 = const Color(0xFF2C3E50);
  final Color bgFever2 = const Color(0xFFFD746C);

  late AnimationController _bgController;

  String t(String key) => localizedText[language]![key] ?? key;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _musicPlayer.setReleaseMode(ReleaseMode.loop);

    loadGameData();
    _loadBannerAd();
    _loadRewardedAd();
    _loadInterstitialAd();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _waitTaskTimer?.cancel();
    _giftSpawnTimer?.cancel();
    _bgController.dispose();
    _sfxPlayer.dispose();
    _musicPlayer.dispose();
    _bannerAd?.dispose();
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  // --- REKLAM ---
  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _bannerUnitId, request: const AdRequest(), size: AdSize.banner,
      listener: BannerAdListener(onAdLoaded: (_) => setState(() => _isBannerReady = true), onAdFailedToLoad: (ad, err) { ad.dispose(); _isBannerReady = false; }),
    )..load();
  }
  void _loadRewardedAd() {
    RewardedAd.load(adUnitId: _rewardedUnitId, request: const AdRequest(), rewardedAdLoadCallback: RewardedAdLoadCallback(onAdLoaded: (ad) => _rewardedAd = ad, onAdFailedToLoad: (err) => _rewardedAd = null));
  }
  void _loadInterstitialAd() {
    InterstitialAd.load(adUnitId: _interstitialUnitId, request: const AdRequest(), adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) { _interstitialAd = ad; _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(onAdDismissedFullScreenContent: (ad) { ad.dispose(); _loadInterstitialAd(); }, onAdFailedToShowFullScreenContent: (ad, err) { ad.dispose(); _loadInterstitialAd(); }); },
          onAdFailedToLoad: (err) => _interstitialAd = null));
  }
  void showInterstitialAd() { if (_interstitialAd != null) { _interstitialAd!.show(); _interstitialAd = null; } }

  // --- KAYIT SİSTEMİ ---
  Future<void> saveGameData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('totalCandy', totalCandy);
    
    // Envanteri kaydet
    await prefs.setInt('inv_heart', inventory["heart"] ?? 0);
    await prefs.setInt('inv_time', inventory["time_potion"] ?? 0);
    await prefs.setInt('inv_sugar', inventory["sugar_potion"] ?? 0);
    await prefs.setInt('inv_sugar_x3', inventory["sugar_x3"] ?? 0);
    await prefs.setInt('inv_reflex', inventory["reflex_serum"] ?? 0);
    await prefs.setInt('inv_math', inventory["math_serum"] ?? 0);
    await prefs.setInt('inv_color', inventory["color_serum"] ?? 0);
    await prefs.setInt('inv_emoji', inventory["emoji_serum"] ?? 0);
    
    // Beyin verileri
    await prefs.setDouble('brainStability', brainStability);
    await prefs.setDouble('sec_reflex', brainSections["Refleks"] ?? 0);
    await prefs.setDouble('sec_perception', brainSections["Algı"] ?? 0);
    await prefs.setDouble('sec_logic', brainSections["Mantık"] ?? 0);
    await prefs.setDouble('sec_emotion', brainSections["Duygu"] ?? 0);
    await prefs.setDouble('sec_control', brainSections["Kontrol"] ?? 0);
    
    // Günlük test
    if (lastDailyTestDate != null) {
      await prefs.setString('lastDailyTestDate', lastDailyTestDate!);
    }
    
    await prefs.setDouble('soundVolume', soundVolume);
    await prefs.setDouble('musicVolume', musicVolume);
    await prefs.setString('language', language);
  }

  Future<void> loadGameData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      totalCandy = prefs.getInt('totalCandy') ?? 1000;
      
      inventory["heart"] = prefs.getInt('inv_heart') ?? 0;
      inventory["time_potion"] = prefs.getInt('inv_time') ?? 0;
      inventory["sugar_potion"] = prefs.getInt('inv_sugar') ?? 0;
      inventory["sugar_x3"] = prefs.getInt('inv_sugar_x3') ?? 0;
      inventory["reflex_serum"] = prefs.getInt('inv_reflex') ?? 0;
      inventory["math_serum"] = prefs.getInt('inv_math') ?? 0;
      inventory["color_serum"] = prefs.getInt('inv_color') ?? 0;
      inventory["emoji_serum"] = prefs.getInt('inv_emoji') ?? 0;

      brainStability = prefs.getDouble('brainStability') ?? 50.0;
      brainSections["Refleks"] = prefs.getDouble('sec_reflex') ?? 10.0;
      brainSections["Algı"] = prefs.getDouble('sec_perception') ?? 10.0;
      brainSections["Mantık"] = prefs.getDouble('sec_logic') ?? 10.0;
      brainSections["Duygu"] = prefs.getDouble('sec_emotion') ?? 10.0;
      brainSections["Kontrol"] = prefs.getDouble('sec_control') ?? 10.0;
      
      lastDailyTestDate = prefs.getString('lastDailyTestDate');
      
      soundVolume = prefs.getDouble('soundVolume') ?? 1.0;
      musicVolume = prefs.getDouble('musicVolume') ?? 0.5;
      language = prefs.getString('language') ?? "TR";
      
      manageBackgroundMusic();
    });
  }

  // --- SES & MÜZİK ---
  void playSound(String fileName) async {
    if (soundVolume <= 0) return;
    try {
      final player = AudioPlayer();
      await player.setVolume(soundVolume);
      await player.play(AssetSource('audio/$fileName'), mode: PlayerMode.lowLatency);
    } catch (_) {}
  }

  void manageBackgroundMusic() async {
    if (musicVolume <= 0 || !isPlaying) {
      await _musicPlayer.stop();
      currentMusicTrack = null;
      return;
    }
    String target = isFeverMode ? "bg_music_fever.mp3" : "bg_music_normal.mp3";
    await _musicPlayer.setVolume(musicVolume);
    if (currentMusicTrack == target) return;
    try {
      await _musicPlayer.stop();
      await _musicPlayer.setSource(AssetSource('audio/$target'));
      await _musicPlayer.resume();
      currentMusicTrack = target;
    } catch (_) {}
  }

  // --- OYUN MANTIĞI ---
  void setNextMotivationTarget() { nextMotivationTarget = score + Random().nextInt(8) + 3; }

  void triggerMotivation() {
    playSound("motivation_hit.mp3");
    List<String> mots = ["mot_1", "mot_2", "mot_3", "mot_4", "mot_5"];
    setState(() {
      currentMotivationText = t(mots[Random().nextInt(mots.length)]);
      showMotivation = true;
    });
    Future.delayed(const Duration(milliseconds: 1500), () { if (mounted) setState(() => showMotivation = false); });
    setNextMotivationTarget();
  }

  void startGame({bool isRevive = false, bool isDaily = false}) {
    playSound("ui_click.mp3");

    setState(() {
      isPlaying = true;
      isDailyTestActive = isDaily;
      
      if (!isRevive) {
        score = 0;
        level = 1;
        speedComboCount = 0;
        earnedCandyThisRound = 0;
        speedMilliseconds = 3000;
        
        // Reset Flags
        activeSecondChance = false;
        activeTimeSlow = false;
        activeDoubleCandy = false;
        activeTripleCandy = false;
        activeReflexOnly = false;
        activeMathOnly = false;
        activeColorOnly = false;
        activeEmojiOnly = false;
        isFeverMode = false;
        
        // Günlük testte eşya harcanmaz
        if (!isDaily) {
          bool anyBuffActive = false;
          if ((inventory["heart"] ?? 0) > 0) {
            activeSecondChance = true; inventory["heart"] = inventory["heart"]! - 1; anyBuffActive = true;
          }
          if ((inventory["time_potion"] ?? 0) > 0) {
            activeTimeSlow = true; inventory["time_potion"] = inventory["time_potion"]! - 1; anyBuffActive = true;
          }
          if ((inventory["sugar_x3"] ?? 0) > 0) {
             activeTripleCandy = true; inventory["sugar_x3"] = inventory["sugar_x3"]! - 1; anyBuffActive = true;
          } else if ((inventory["sugar_potion"] ?? 0) > 0) {
             activeDoubleCandy = true; inventory["sugar_potion"] = inventory["sugar_potion"]! - 1; anyBuffActive = true;
          }
          if ((inventory["reflex_serum"] ?? 0) > 0) {
             activeReflexOnly = true; inventory["reflex_serum"] = inventory["reflex_serum"]! - 1; anyBuffActive = true;
          } else if ((inventory["math_serum"] ?? 0) > 0) {
             activeMathOnly = true; inventory["math_serum"] = inventory["math_serum"]! - 1; anyBuffActive = true;
          } else if ((inventory["color_serum"] ?? 0) > 0) {
             activeColorOnly = true; inventory["color_serum"] = inventory["color_serum"]! - 1; anyBuffActive = true;
          } else if ((inventory["emoji_serum"] ?? 0) > 0) {
             activeEmojiOnly = true; inventory["emoji_serum"] = inventory["emoji_serum"]! - 1; anyBuffActive = true;
          }

          if (anyBuffActive) {
            playSound("equip_potion.mp3");
            saveGameData();
          }
        }
      } else {
        activeSecondChance = true; // Canlanınca kalkan
        playSound("equip_potion.mp3");
      }

      setNextMotivationTarget();
      resetGift();
      startGiftSpawner();
      nextTask();
      manageBackgroundMusic();
    });
    startTimer();
  }

  void startTimer() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!isPlaying) return;
      setState(() {
        double baseDecay = 16.0 / speedMilliseconds;
        if (activeTimeSlow) baseDecay *= 0.7;
        if (isFeverMode) baseDecay *= 0.8;
        progress -= baseDecay;
        if (progress <= 0) gameOver(t("game_over_time"));
      });
    });
  }

  void startGiftSpawner() {
    if (isDailyTestActive) return; // Günlük testte hediye çıkmaz
    int randomTime = Random().nextInt(8) + 5;
    _giftSpawnTimer = Timer(Duration(seconds: randomTime), () { if (isPlaying) spawnGift(); });
  }

  void spawnGift() {
    if (!mounted || !isPlaying) return;
    playSound("gift_appear.mp3");
    setState(() {
      isGiftVisible = true;
      giftBonusText = "";
      isBonusTextVisible = false;
      giftTopPosition = Random().nextDouble() * (MediaQuery.of(context).size.height * 0.4) + 100;
      giftLeftPosition = Random().nextBool() ? 20.0 : MediaQuery.of(context).size.width - 100.0;
    });
    Future.delayed(const Duration(seconds: 4), () { if (mounted && isGiftVisible) { setState(() => isGiftVisible = false); startGiftSpawner(); } });
  }

  void collectGift() {
    if (!isGiftVisible) return;
    playSound("gift_collect.mp3");
    int baseBonus = Random().nextInt(50) + 20;
    if (activeDoubleCandy) baseBonus *= 2;
    if (activeTripleCandy) baseBonus *= 3;

    setState(() {
      isGiftVisible = false;
      earnedCandyThisRound += baseBonus;
      if (soundVolume > 0) HapticFeedback.heavyImpact();
      giftBonusText = "+$baseBonus 🍬";
      isBonusTextVisible = true;
    });
    Future.delayed(const Duration(seconds: 1), () { if(mounted) setState(() => isBonusTextVisible = false); startGiftSpawner(); });
  }

  void resetGift() {
    _giftSpawnTimer?.cancel();
    setState(() { isGiftVisible = false; isBonusTextVisible = false; showMotivation = false; });
  }

  // --- GÖREV ÜRETİMİ ---
  void nextTask() {
    _waitTaskTimer?.cancel();
    _taskStartTime = DateTime.now();

    setState(() {
      progress = 1.0;
      level = (score / 10).floor() + 1;

      bool wasFever = isFeverMode;
      if (speedComboCount >= 4) isFeverMode = true; else isFeverMode = false;
      
      if (wasFever != isFeverMode) {
        if (isFeverMode) playSound("fever_start.mp3");
        manageBackgroundMusic();
      }

      if (score > 0 && score % 5 == 0) speedMilliseconds = (speedMilliseconds * 0.95).toInt();

      // --- MOD KONTROLÜ ---
      if (activeReflexOnly) {
         currentTask = TaskType.direction;
         currentDirection = Direction.values[Random().nextInt(4)];
         isReverseRound = Random().nextDouble() > 0.3;
      } else if (activeMathOnly) {
         currentTask = TaskType.math;
         generateMathTask();
      } else if (activeColorOnly) {
         currentTask = Random().nextBool() ? TaskType.color : TaskType.notColor;
         generateColorTask(currentTask == TaskType.notColor);
      } else if (activeEmojiOnly) {
         currentTask = TaskType.emoji;
         generateEmojiTask();
      } else {
         // Normal Rastgele
         double rng = Random().nextDouble();
         if (level >= 2 && rng > 0.90) {
           currentTask = TaskType.wait;
           startWaitTaskLogic();
         } else {
           double subRng = Random().nextDouble();
           if (subRng < 0.25) {
             currentTask = TaskType.direction;
             currentDirection = Direction.values[Random().nextInt(4)];
             isReverseRound = Random().nextDouble() > 0.3;
           } else if (subRng < 0.45) {
             currentTask = TaskType.color;
             generateColorTask(false);
           } else if (subRng < 0.60) {
             currentTask = TaskType.notColor;
             generateColorTask(true);
           } else if (subRng < 0.80) {
             currentTask = TaskType.math;
             generateMathTask();
           } else {
             currentTask = TaskType.emoji;
             generateEmojiTask();
           }
         }
      }
    });
  }

  void startWaitTaskLogic() {
    int waitDuration = (speedMilliseconds * 0.5).toInt();
    _waitTaskTimer = Timer(Duration(milliseconds: waitDuration), () { if (isPlaying && currentTask == TaskType.wait) handleResult(true); });
  }

  void generateColorTask(bool isNot) {
    List<String> names = language == "TR" 
        ? ["MAVİ", "KIRMIZI", "YEŞİL", "SARI", "MOR"] 
        : ["BLUE", "RED", "GREEN", "YELLOW", "PURPLE"];
    List<Color> colors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple];
    
    int tIdx = Random().nextInt(5);
    int cIdx = Random().nextInt(5);
    colorText = names[tIdx];
    colorInk = colors[cIdx];

    if (isNot) {
      colorInstruction = "${names[tIdx]} ${t("not_color_q")}";
      correctColor = Colors.black;
    } else {
      bool askForInk = Random().nextBool();
      colorInstruction = askForInk ? t("color_ink") : t("color_text");
      correctColor = askForInk ? colors[cIdx] : colors[tIdx];
    }
    
    int optionCount = level >= 2 ? 3 : 2;
    if (level >= 3) optionCount = 4;
    colorOptions = [];
    if (isNot) {
       Color forbiddenColor = colors[tIdx];
       colorOptions.add(forbiddenColor);
       while (colorOptions.length < optionCount) { Color w = colors[Random().nextInt(5)]; if (!colorOptions.contains(w)) colorOptions.add(w); }
    } else {
       colorOptions.add(correctColor);
       while (colorOptions.length < optionCount) { Color w = colors[Random().nextInt(5)]; if (!colorOptions.contains(w)) colorOptions.add(w); }
    }
    colorOptions.shuffle();
  }

  void generateMathTask() {
    int n1 = Random().nextInt(9) + 1;
    int n2 = Random().nextInt(9) + 1;
    int realSum = n1 + n2;
    isMathCorrect = Random().nextBool();
    int shownSum = isMathCorrect ? realSum : realSum + (Random().nextBool() ? 1 : -1);
    if (shownSum == realSum && !isMathCorrect) shownSum += 1;
    mathEquation = "$n1 + $n2 = $shownSum";
  }

  void generateEmojiTask() {
    List<Map<String, String>> data = language == "TR" 
        ? [{"w": "MUTLU", "e": "😊"}, {"w": "ÜZGÜN", "e": "😢"}, {"w": "KIZGIN", "e": "😡"}, {"w": "ŞAŞKIN", "e": "😲"}, {"w": "AŞIK", "e": "😍"}]
        : [{"w": "HAPPY", "e": "😊"}, {"w": "SAD", "e": "😢"}, {"w": "ANGRY", "e": "😡"}, {"w": "SHOCKED", "e": "😲"}, {"w": "LOVE", "e": "😍"}];
    var target = data[Random().nextInt(data.length)];
    emojiText = target["w"]!; correctEmoji = target["e"]!;
    emojiOptions = [correctEmoji];
    while (emojiOptions.length < 3) { String wrong = data[Random().nextInt(data.length)]["e"]!; if (!emojiOptions.contains(wrong)) emojiOptions.add(wrong); }
    emojiOptions.shuffle();
  }

  // --- KONTROLLER ---
  void checkSwipe(Direction input) {
    if (!isPlaying) return;
    if (currentTask == TaskType.wait) { gameOver(t("game_over_touch")); return; }
    if (currentTask == TaskType.direction) {
      bool success = false;
      if (isReverseRound) {
        if (currentDirection == Direction.up && input == Direction.down) success = true;
        if (currentDirection == Direction.down && input == Direction.up) success = true;
        if (currentDirection == Direction.left && input == Direction.right) success = true;
        if (currentDirection == Direction.right && input == Direction.left) success = true;
      } else {
        if (currentDirection == input) success = true;
      }
      handleResult(success);
    }
  }

  void checkColor(Color selectedColor) {
    if (!isPlaying) return;
    if (currentTask == TaskType.wait) { gameOver(t("game_over_touch")); return; }
    if (currentTask == TaskType.notColor) {
      bool isForbidden = false;
      if ((colorText.contains("KIRM") || colorText.contains("RED")) && selectedColor == Colors.red) isForbidden = true;
      if ((colorText.contains("MAV") || colorText.contains("BLUE")) && selectedColor == Colors.blue) isForbidden = true;
      if ((colorText.contains("YEŞ") || colorText.contains("GREEN")) && selectedColor == Colors.green) isForbidden = true;
      if ((colorText.contains("SAR") || colorText.contains("YELLOW")) && selectedColor == Colors.orange) isForbidden = true;
      if ((colorText.contains("MOR") || colorText.contains("PURPLE")) && selectedColor == Colors.purple) isForbidden = true;
      handleResult(!isForbidden);
    } else {
      handleResult(selectedColor == correctColor);
    }
  }

  void checkMath(bool val) { if (isPlaying) handleResult(val == isMathCorrect); }
  void checkEmoji(String val) { if (isPlaying) handleResult(val == correctEmoji); }
  void checkScreenTap() { if (isPlaying && currentTask == TaskType.wait) gameOver(t("game_over_hand")); }

  // --- SONUÇ ---
  void handleResult(bool success) {
    if (success) {
      if (soundVolume > 0) HapticFeedback.lightImpact();
      playSound("pop_correct.mp3");

      double stabilityGain = 0.3;
      if (isFeverMode) stabilityGain = 0.6;
      int reactionTime = DateTime.now().difference(_taskStartTime).inMilliseconds;
      if (reactionTime < 1000) stabilityGain += 0.2;
      
      setState(() {
        brainStability = (brainStability + stabilityGain).clamp(0.0, 100.0);
        
        double sectionGain = 0.5; 
        String sectionKey = "Kontrol";
        if (currentTask == TaskType.direction) sectionKey = "Refleks";
        if (currentTask == TaskType.color || currentTask == TaskType.notColor) sectionKey = "Algı";
        if (currentTask == TaskType.math) sectionKey = "Mantık";
        if (currentTask == TaskType.emoji) sectionKey = "Duygu";
        
        brainSections[sectionKey] = (brainSections[sectionKey]! + sectionGain).clamp(0.0, 100.0);

        int point = isFeverMode ? 2 : 1;
        if (activeDoubleCandy) point *= 2;
        if (activeTripleCandy) point *= 3; 

        score += (isFeverMode ? 2 : 1);
        earnedCandyThisRound += point;
        
        if (reactionTime < 1500) speedComboCount++; else speedComboCount = 0;
        if (score >= nextMotivationTarget) triggerMotivation();
      });
      nextTask();
    } else {
      speedComboCount = 0;
      if (activeSecondChance) {
        if (soundVolume > 0) HapticFeedback.mediumImpact();
        playSound("shield_break.mp3");
        setState(() => activeSecondChance = false);
        showToast(t("shield_broken"), Colors.cyan);
        nextTask();
      } else {
        playSound("wrong_buzz.mp3");
        setState(() { brainStability = (brainStability - 1.0).clamp(0.0, 100.0); });
        gameOver(t("game_over_wrong"));
      }
    }
  }

  void showToast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), backgroundColor: color, duration: const Duration(seconds: 1), behavior: SnackBarBehavior.floating, margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height - 150, left: 20, right: 20)));
  }

  void gameOver(String reason) {
    playSound("game_over.mp3");
    if (soundVolume > 0) HapticFeedback.heavyImpact();
    isPlaying = false;
    manageBackgroundMusic();
    _gameTimer?.cancel();
    _waitTaskTimer?.cancel();
    resetGift();
    deathCount++;
    if (deathCount % 3 == 0) showInterstitialAd();

    setState(() {
      if (!isDailyTestActive) { // Günlük testte ceza yok
        brainStability = (brainStability - 5.0).clamp(0.0, 100.0);
      }
      if (isDailyTestActive) {
         lastDailyTestDate = "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}";
      }
    });

    totalCandy += earnedCandyThisRound;
    saveGameData();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Material(
          color: Colors.transparent,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: ModalRoute.of(context)!.animation!, curve: Curves.elasticOut),
            child: JellyBox(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t("game_report"), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.blueGrey)),
                  const SizedBox(height: 10),
                  Text(reason, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  const Divider(),
                  _buildStatRow(t("reflex"), brainSections["Refleks"]!, Colors.blue),
                  _buildStatRow(t("perception"), brainSections["Algı"]!, Colors.green),
                  _buildStatRow(t("logic"), brainSections["Mantık"]!, Colors.orange),
                  _buildStatRow(t("emotion"), brainSections["Duygu"]!, Colors.purple),
                  const SizedBox(height: 15),
                  Text("${t("score")}: $score", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text("+ $earnedCandyThisRound 🍬", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  if (!isDailyTestActive) 
                    GestureDetector(
                      onTap: () { 
                        Navigator.pop(context); 
                        showRewardedAdForRevive(); 
                      }, 
                      child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), decoration: BoxDecoration(color: Colors.yellow[700], borderRadius: BorderRadius.circular(20)), child: Text(t("revive") + " (📺)", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)))
                    ),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    IconButton(icon: const Icon(Icons.home, size: 30), onPressed: () => Navigator.pop(context)),
                    const SizedBox(width: 20),
                    JellyButton(text: t("retry"), onTap: () { Navigator.pop(context); startGame(isDaily: isDailyTestActive); }, color: primaryPink, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10))
                  ])
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, double val, Color color) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [Expanded(flex: 2, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))), Expanded(flex: 5, child: LinearProgressIndicator(value: val / 100, color: color, backgroundColor: Colors.grey[200])), Expanded(flex: 2, child: Text(" %${val.toInt()}", style: const TextStyle(fontSize: 12)))]));
  }

  void showRewardedAdForRevive() {
    if (_rewardedAd != null) {
      _rewardedAd!.show(onUserEarnedReward: (_, __) { startGame(isRevive: true); showToast(t("revive_active_msg"), Colors.green); });
      _rewardedAd = null; _loadRewardedAd();
    } else { 
      showToast(t("ad_loading"), Colors.orange);
      _loadRewardedAd();
    }
  }

  // --- MARKET ---
  void openShop() {
    playSound("ui_popup.mp3");
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.95,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Colors.white, Color(0xFFFFF0F5)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 15),
                Text(t("shop_title"), style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: primaryPink)),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: primaryPink)),
                  child: Text("${t("balance")}: $totalCandy 🍬", style: TextStyle(fontSize: 18, color: Colors.purple[800], fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t("sec_powerups"), style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                          childAspectRatio: 0.8,
                          children: [
                            _buildShopItem(t("item_heart"), t("desc_heart"), "heart", 500, Icons.favorite, Colors.red, setModalState),
                            _buildShopItem(t("item_time"), t("desc_time"), "time_potion", 800, Icons.hourglass_bottom, Colors.purple, setModalState),
                            _buildShopItem(t("item_sugar"), t("desc_sugar"), "sugar_potion", 1000, Icons.casino, Colors.orange, setModalState),
                            _buildShopItem(t("item_sugar_x3"), t("desc_sugar_x3"), "sugar_x3", 2000, Icons.flash_on, Colors.yellow[800]!, setModalState),
                          ],
                        ),
                        const SizedBox(height: 25),
                        Text(t("sec_modes"), style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                          childAspectRatio: 0.8,
                          children: [
                            _buildShopItem(t("item_reflex"), t("desc_reflex"), "reflex_serum", 1500, Icons.bolt, Colors.blue, setModalState),
                            _buildShopItem(t("item_math"), t("desc_math"), "math_serum", 1500, Icons.calculate, Colors.orange, setModalState),
                            _buildShopItem(t("item_color"), t("desc_color"), "color_serum", 1500, Icons.palette, Colors.green, setModalState),
                            _buildShopItem(t("item_emoji"), t("desc_emoji"), "emoji_serum", 1500, Icons.emoji_emotions, Colors.purpleAccent, setModalState),
                          ],
                        ),
                        const SizedBox(height: 25),
                        Text(t("sec_repair"), style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        _buildRepairItem(t("repair_general"), "brainStability", 500, Colors.redAccent, setModalState),
                        _buildRepairItem(t("repair_reflex"), "Refleks", 200, Colors.blue, setModalState),
                        _buildRepairItem(t("repair_logic"), "Mantık", 200, Colors.orange, setModalState),
                        _buildRepairItem(t("repair_perception"), "Algı", 200, Colors.green, setModalState),
                        _buildRepairItem(t("repair_emotion"), "Duygu", 200, Colors.purple, setModalState),
                        _buildRepairItem(t("repair_control"), "Kontrol", 200, Colors.grey, setModalState),
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: JellyButton(
                    text: t("close"),
                    onTap: () { playSound("ui_click.mp3"); Navigator.pop(context); },
                    color: Colors.grey,
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildShopItem(String name, String desc, String id, int price, IconData icon, Color color, StateSetter setModalState) {
    int owned = inventory[id] ?? 0;
    bool canBuy = totalCandy >= price;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0,5))],
        border: Border.all(color: canBuy ? color.withOpacity(0.5) : Colors.grey[200]!, width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (canBuy) {
              playSound("buy_cha_ching.mp3");
              setState(() {
                totalCandy -= price;
                inventory[id] = (inventory[id] ?? 0) + 1;
              });
              setModalState((){});
              saveGameData();
            } else {
              playSound("wrong_buzz.mp3");
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(radius: 22, backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 28)),
                const SizedBox(height: 8),
                Text(name, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1),
                Text(desc, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 2, overflow: TextOverflow.ellipsis),
                const Spacer(),
                Text("${t("bag")}: $owned", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: canBuy ? color : Colors.grey, borderRadius: BorderRadius.circular(10)),
                  child: Text("$price 🍬", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRepairItem(String label, String key, int price, Color color, StateSetter setModalState) {
    double currentVal = key == "brainStability" ? brainStability : brainSections[key]!;
    bool isMax = currentVal >= 100;
    bool canBuy = totalCandy >= price;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey[200]!)),
      child: ListTile(
        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.medical_services, color: color)),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: LinearProgressIndicator(value: currentVal / 100, color: color, backgroundColor: Colors.grey[100], minHeight: 6, borderRadius: BorderRadius.circular(5)),
        trailing: isMax 
          ? const Icon(Icons.check_circle, color: Colors.green)
          : ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: canBuy ? primaryPink : Colors.grey, elevation: 0, shape: const StadiumBorder()),
              onPressed: () {
                 if (canBuy) {
                    playSound("buy_cha_ching.mp3");
                    setState(() {
                      totalCandy -= price;
                      if (key == "brainStability") brainStability = (brainStability + 10).clamp(0.0, 100.0);
                      else brainSections[key] = (brainSections[key]! + 10).clamp(0.0, 100.0);
                    });
                    setModalState((){});
                    saveGameData();
                 } else playSound("wrong_buzz.mp3");
              },
              child: Text("$price 🍬"),
            ),
      ),
    );
  }

  void openSettings() {
    playSound("ui_popup.mp3");
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Center(
              child: Material(
                color: Colors.transparent,
                child: JellyBox(
                  padding: const EdgeInsets.all(20),
                  color: Colors.white,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(t("settings"), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text("${t("sound")}: ${(soundVolume * 100).toInt()}%", style: const TextStyle(fontSize: 16)),
                            Slider(value: soundVolume, min: 0.0, max: 1.0, activeColor: primaryPink,
                              onChanged: (val) { setDialogState(() => soundVolume = val); setState(() => soundVolume = val); },
                              onChangeEnd: (val) { playSound("ui_click.mp3"); saveGameData(); },
                            ),
                          ]),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text("${t("music")}: ${(musicVolume * 100).toInt()}%", style: const TextStyle(fontSize: 16)),
                            Slider(value: musicVolume, min: 0.0, max: 1.0, activeColor: primaryPink,
                              onChanged: (val) { setDialogState(() => musicVolume = val); setState(() { musicVolume = val; manageBackgroundMusic(); }); },
                              onChangeEnd: (val) => saveGameData(),
                            ),
                          ]),
                      ),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(t("lang"), style: const TextStyle(fontWeight: FontWeight.bold)),
                          Row(children: [ _buildLangButton("TR", setDialogState), const SizedBox(width: 5), _buildLangButton("EN", setDialogState)]),
                        ]),
                      const SizedBox(height: 20),
                      JellyButton(
                        text: t("close"),
                        onTap: () { playSound("ui_click.mp3"); Navigator.pop(context); },
                        color: Colors.grey,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        fontSize: 16,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLangButton(String code, StateSetter setDialogState) {
    bool isSelected = language == code;
    return GestureDetector(
      onTap: () {
        playSound("ui_click.mp3");
        setDialogState(() => language = code);
        setState(() => language = code);
        saveGameData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: isSelected ? primaryPink : Colors.grey[200], borderRadius: BorderRadius.circular(8)),
        child: Text(code, style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  double _getRotation() {
    if (currentDirection == Direction.right) return 0;
    if (currentDirection == Direction.down) return pi / 2;
    if (currentDirection == Direction.left) return pi;
    return -pi / 2;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: checkScreenTap,
        onVerticalDragEnd: (d) { if (d.primaryVelocity! < 0) checkSwipe(Direction.up); else if (d.primaryVelocity! > 0) checkSwipe(Direction.down); },
        onHorizontalDragEnd: (d) { if (d.primaryVelocity! < 0) checkSwipe(Direction.left); else if (d.primaryVelocity! > 0) checkSwipe(Direction.right); },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomRight, colors: [bgNormal1, bgNormal2]))),
            
            // SÜREKLİ AKAN ARKA PLAN
            AnimatedBuilder(
              animation: _bgController,
              builder: (context, child) => CustomPaint(painter: FloatingCandyPainter(_bgController.value)),
            ),
            
            AnimatedPositioned(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOutCubic,
              top: isFeverMode ? 0 : -(MediaQuery.of(context).size.height + 20),
              left: 0, right: 0, height: MediaQuery.of(context).size.height + 20,
              child: Container(
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomRight, colors: [bgFever1, bgFever2, Colors.purple])),
                child: AnimatedBuilder(animation: _bgController, builder: (_,__) => CustomPaint(painter: FloatingCandyPainter(_bgController.value))),
              ),
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                             const Icon(Icons.health_and_safety, color: Colors.redAccent),
                             const SizedBox(width: 5),
                             Text("%${brainStability.toInt()}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.white)),
                          ]),
                          Text(t("repair_general"), style: const TextStyle(fontSize: 10, color: Colors.white70)),
                        ]),
                        
                        if (isPlaying)
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                           Text("${t("score")}: $score", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                           if (isFeverMode) Text(t("fever"), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.yellow, shadows: [Shadow(blurRadius: 10, color: Colors.red)])),
                        ]),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: Colors.white54, borderRadius: BorderRadius.circular(15)),
                          child: Text("$totalCandy 🍬", style: const TextStyle(fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                    
                    Expanded(
                      child: Center(
                        child: isPlaying ? _buildGameContent() : _buildMainMenu(),
                      ),
                    ),

                    if (isPlaying)
                       ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: progress, minHeight: 15, color: isFeverMode ? Colors.red : Colors.white)),
                  ],
                ),
              ),
            ),
            
            if (isGiftVisible) Positioned(top: giftTopPosition, left: giftLeftPosition, child: GestureDetector(onTap: collectGift, child: ShakeWidget(child: Image.asset('assets/gift.png', width: 80, height: 80)))),
            if (isBonusTextVisible) Positioned(top: giftTopPosition, left: giftLeftPosition + 10, child: Material(color: Colors.transparent, child: Text(giftBonusText, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.yellowAccent, shadows: [Shadow(color: Colors.black, blurRadius: 5)])))),
            if (showMotivation) Positioned(top: 60, left: 0, right: 0, child: Center(child: IgnorePointer(child: TweenAnimationBuilder<double>(tween: Tween(begin: 0.0, end: 1.0), duration: const Duration(milliseconds: 300), curve: Curves.elasticOut, builder: (context, val, child) { return Transform.scale(scale: val, child: Transform.rotate(angle: -0.05, child: Container(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: primaryPink, width: 4), boxShadow: const [BoxShadow(color: Colors.black12, offset: Offset(0, 10), blurRadius: 10)]), child: Text(currentMotivationText, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: primaryPink, letterSpacing: 2))))); })))),
          ],
        ),
      ),
      bottomNavigationBar: _isBannerReady ? SizedBox(height: _bannerAd!.size.height.toDouble(), width: _bannerAd!.size.width.toDouble(), child: AdWidget(ad: _bannerAd!)) : null,
    );
  }

  Widget _buildMainMenu() {
    String todayStr = "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}";
    bool isDailyDone = lastDailyTestDate == todayStr;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.flash_on_rounded, size: 60, color: Colors.white),
        const ThreeDText(text: "BRAIN\nGLITCH", fontSize: 50, lineHeight: 0.9),
        const SizedBox(height: 10),
        Text(t("slogan"), style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic)),
        const SizedBox(height: 40),
        
        // GÜNLÜK TEST BUTONU
        GestureDetector(
          onTap: isDailyDone ? null : () => startGame(isDaily: true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            decoration: BoxDecoration(
              color: isDailyDone ? Colors.grey : Colors.orangeAccent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [BoxShadow(color: Colors.black26, offset: Offset(0, 4), blurRadius: 4)],
            ),
            child: Text(isDailyDone ? t("daily_done") : t("daily_test"), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
        
        const SizedBox(height: 20),

        JellyButton(text: t("start"), onTap: () => startGame(), color: accentCyan, padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 25), fontSize: 35),
        const SizedBox(height: 20),
        
        if (inventory.values.any((val) => val > 0))
            Container(margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(10)), child: Text(t("item_warning"), style: TextStyle(color: Colors.purple[900], fontWeight: FontWeight.bold))),

        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
           _buildMiniButton(Icons.shopping_cart, Colors.orange, openShop),
           const SizedBox(width: 20),
           _buildMiniButton(Icons.settings, Colors.purple, openSettings), 
        ]),
      ],
    );
  }

  Widget _buildGameContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // AKTİF BUFF GÖSTERGESİ
        if (activeSecondChance || activeTimeSlow || activeDoubleCandy || activeTripleCandy || activeReflexOnly || activeMathOnly || activeColorOnly || activeEmojiOnly)
            Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (activeSecondChance) const Padding(padding: EdgeInsets.symmetric(horizontal: 5), child: Icon(Icons.favorite, color: Colors.red, size: 30)),
                  if (activeTimeSlow) const Padding(padding: EdgeInsets.symmetric(horizontal: 5), child: Icon(Icons.hourglass_bottom, color: Colors.purpleAccent, size: 30)),
                  if (activeDoubleCandy) const Padding(padding: EdgeInsets.symmetric(horizontal: 5), child: Icon(Icons.casino, color: Colors.orangeAccent, size: 30)),
                  if (activeTripleCandy) const Padding(padding: EdgeInsets.symmetric(horizontal: 5), child: Icon(Icons.flash_on, color: Colors.yellowAccent, size: 30)),
                  if (activeReflexOnly) const Padding(padding: EdgeInsets.symmetric(horizontal: 5), child: Icon(Icons.bolt, color: Colors.blueAccent, size: 30)),
                  if (activeMathOnly) const Padding(padding: EdgeInsets.symmetric(horizontal: 5), child: Icon(Icons.calculate, color: Colors.orange, size: 30)),
                  if (activeColorOnly) const Padding(padding: EdgeInsets.symmetric(horizontal: 5), child: Icon(Icons.palette, color: Colors.green, size: 30)),
                  if (activeEmojiOnly) const Padding(padding: EdgeInsets.symmetric(horizontal: 5), child: Icon(Icons.emoji_emotions, color: Colors.purple, size: 30)),
             ])),

        // OYUN İÇERİĞİ (GÖREVLER)
        if (currentTask == TaskType.direction) ...[
          const Spacer(),
          JellyBox(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20), color: isReverseRound ? Colors.redAccent : Colors.greenAccent, child: ThreeDText(text: isReverseRound ? t("reverse") : t("same"), fontSize: 32)),
          const SizedBox(height: 30),
          Expanded(flex: 3, child: Transform.rotate(angle: _getRotation(), child: JellyBox(isCircle: true, padding: const EdgeInsets.all(30), color: Colors.white.withOpacity(0.5), child: SizedBox(width: 200, height: 200, child: Image.asset('assets/arrow.png', fit: BoxFit.contain))))),
          ThreeDText(text: t("swipe"), fontSize: 28),
          const Spacer(),
        ] else if (currentTask == TaskType.wait) ...[
          const Spacer(),
          JellyBox(padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15), color: Colors.orange, child: ThreeDText(text: t("dont_touch"), fontSize: 35)),
          const SizedBox(height: 40),
          Expanded(flex: 3, child: Center(child: JellyBox(isCircle: true, padding: const EdgeInsets.all(40), color: Colors.redAccent, child: SizedBox(width: 150, height: 150, child: Image.asset('assets/pause.png', fit: BoxFit.contain))))),
          ThreeDText(text: t("wait"), fontSize: 28),
          const Spacer(),
        ] else if (currentTask == TaskType.math) ...[
          const Spacer(),
          ThreeDText(text: t("math_q"), fontSize: 28),
          const SizedBox(height: 30),
          JellyBox(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40), color: Colors.white, child: Text(mathEquation, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.indigo))),
          const SizedBox(height: 50),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            JellyButton(text: t("wrong"), onTap: () => checkMath(false), color: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20)),
            const SizedBox(width: 20),
            JellyButton(text: t("correct"), onTap: () => checkMath(true), color: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20)),
          ]),
          const Spacer(),
        ] else if (currentTask == TaskType.emoji) ...[
           const Spacer(),
           ThreeDText(text: t("emoji_q"), fontSize: 28),
           const SizedBox(height: 30),
           JellyBox(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30), color: Colors.white, child: Text(emojiText, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.black87))),
           const Spacer(),
           Row(mainAxisAlignment: MainAxisAlignment.center, children: emojiOptions.map((e) => Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: GestureDetector(onTap: () => checkEmoji(e), child: JellyBox(padding: const EdgeInsets.all(15), color: Colors.white.withOpacity(0.5), child: Text(e, style: const TextStyle(fontSize: 50)))))).toList()),
           const Spacer(),
        ] else ...[
           const Spacer(),
           ThreeDText(text: colorInstruction, fontSize: 28, isUnderlined: currentTask == TaskType.notColor),
           const SizedBox(height: 20),
           JellyBox(padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 30), color: Colors.white, child: Text(colorText, style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: colorInk))),
           const Spacer(),
           Wrap(spacing: 20, runSpacing: 20, alignment: WrapAlignment.center, children: colorOptions.map((c) => GestureDetector(onTap: () => checkColor(c), child: Container(width: 80, height: 80, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))])) )).toList()),
           const Spacer(),
        ],
      ],
    );
  }

  Widget _buildMiniButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () { playSound("ui_click.mp3"); onTap(); },
      child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: color.withOpacity(0.4), offset: const Offset(0, 5), blurRadius: 0)]), child: Icon(icon, color: color, size: 30)),
    );
  }
}