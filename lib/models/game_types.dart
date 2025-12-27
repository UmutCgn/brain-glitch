enum TaskType { direction, color, wait, math, emoji, notColor }
enum Direction { up, down, left, right }

class SessionMission {
  final String description;
  final int targetCount;
  final String type; // 'total', 'math', 'fever', 'survive', 'daily'
  int currentProgress = 0;
  bool isCompleted = false;

  SessionMission(this.description, this.targetCount, this.type);
}