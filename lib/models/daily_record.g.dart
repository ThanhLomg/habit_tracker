// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DailyRecordAdapter extends TypeAdapter<DailyRecord> {
  @override
  final int typeId = 2;

  @override
  DailyRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyRecord(
      date: fields[0] as DateTime,
      completedHabitsCount: fields[1] as int,
      completedHabitNames: (fields[2] as List).cast<String>(),
      completedTasks: fields[3] as int,
      totalTasks: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, DailyRecord obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.completedHabitsCount)
      ..writeByte(2)
      ..write(obj.completedHabitNames)
      ..writeByte(3)
      ..write(obj.completedTasks)
      ..writeByte(4)
      ..write(obj.totalTasks);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
