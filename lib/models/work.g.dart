part of 'work.dart';

class WorkAdapter extends TypeAdapter<Work> {
  @override
  final int typeId = 1;

  @override
  Work read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Work(
      id: fields[0] as String,
      title: fields[1] as String,
      author: fields[2] as String,
      tags: (fields[3] as List).cast<String>(),
      userAddedDate: fields[11] as DateTime,
      publishedAt: fields[4] as DateTime?,
      updatedAt: fields[5] as DateTime?,
      wordsCount: fields[6] as int?,
      chaptersCount: fields[7] as int?,
      kudosCount: fields[8] as int?,
      hitsCount: fields[9] as int?,
      commentsCount: fields[10] as int?,
      lastSyncDate: fields[12] as DateTime?,
      downloadedAt: fields[13] as DateTime?,
      lastUserOpened: fields[14] as DateTime?,
      isFavorite: fields[15] as bool,
      categoryId: fields[16] as String?,
      readingProgress: fields[17] as ReadingProgress?,
      isDownloaded: fields[18] as bool,
      hasUpdate: fields[19] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Work obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.author)
      ..writeByte(3)
      ..write(obj.tags)
      ..writeByte(4)
      ..write(obj.publishedAt)
      ..writeByte(5)
      ..write(obj.updatedAt)
      ..writeByte(6)
      ..write(obj.wordsCount)
      ..writeByte(7)
      ..write(obj.chaptersCount)
      ..writeByte(8)
      ..write(obj.kudosCount)
      ..writeByte(9)
      ..write(obj.hitsCount)
      ..writeByte(10)
      ..write(obj.commentsCount)
      ..writeByte(11)
      ..write(obj.userAddedDate)
      ..writeByte(12)
      ..write(obj.lastSyncDate)
      ..writeByte(13)
      ..write(obj.downloadedAt)
      ..writeByte(14)
      ..write(obj.lastUserOpened)
      ..writeByte(15)
      ..write(obj.isFavorite)
      ..writeByte(16)
      ..write(obj.categoryId)
      ..writeByte(17)
      ..write(obj.readingProgress)
      ..writeByte(18)
      ..write(obj.isDownloaded)
      ..writeByte(19)
      ..write(obj.hasUpdate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
