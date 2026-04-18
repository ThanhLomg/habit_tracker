// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HabitItemAdapter extends TypeAdapter<HabitItem> {
  @override
  final int typeId = 0;

  @override
  HabitItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HabitItem(
      name: fields[0] as String,
      isCompleted: fields[1] as bool,
      createdAt: fields[2] as DateTime,
      reminderHour: fields[3] as int?,
      reminderMinute: fields[4] as int?,
      note: fields[5] as String?,
      iconCodePoint: fields[6] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, HabitItem obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.isCompleted)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.reminderHour)
      ..writeByte(4)
      ..write(obj.reminderMinute)
      ..writeByte(5)
      ..write(obj.note)
      ..writeByte(6)
      ..write(obj.iconCodePoint);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
