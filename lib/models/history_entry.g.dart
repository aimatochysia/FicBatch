// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HistoryEntryAdapter extends TypeAdapter<HistoryEntry> {
  @override
  final int typeId = 2;

  @override
  HistoryEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HistoryEntry(
      workId: fields[0] as String,
      title: fields[1] as String,
      author: fields[2] as String,
      chapterIndex: fields[3] as int,
      scrollPosition: fields[4] as double,
      accessedAt: fields[5] as DateTime,
      chapterName: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, HistoryEntry obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.workId)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.author)
      ..writeByte(3)
      ..write(obj.chapterIndex)
      ..writeByte(4)
      ..write(obj.scrollPosition)
      ..writeByte(5)
      ..write(obj.accessedAt)
      ..writeByte(6)
      ..write(obj.chapterName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoryEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
