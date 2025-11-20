part of 'reading_progress.dart';

class ReadingProgressAdapter extends TypeAdapter<ReadingProgress> {
  @override
  final int typeId = 0;

  @override
  ReadingProgress read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReadingProgress(
      chapterIndex: fields[0] as int,
      chapterAnchor: fields[1] as String?,
      lastReadAt: fields[2] as DateTime?,
      scrollPosition: fields[3] as double,
      isCompleted: fields[4] as bool,
      chapterName: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ReadingProgress obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.chapterIndex)
      ..writeByte(1)
      ..write(obj.chapterAnchor)
      ..writeByte(2)
      ..write(obj.lastReadAt)
      ..writeByte(3)
      ..write(obj.scrollPosition)
      ..writeByte(4)
      ..write(obj.isCompleted)
      ..writeByte(5)
      ..write(obj.chapterName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadingProgressAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
