/*
 * Copyright 2020 Board of Trustees of the University of Illinois.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'package:illinois/service/AppDateTime.dart';
import 'package:rokwire_plugin/utils/utils.dart';

class ToDoItem {
  static final String _dateTimeFormat = 'yyyy-MM-ddTHH:mm';

  final String? id;
  final String? name;
  final ToDoCategory? category;
  final String? dueDateTimeString;
  final List<String>? workDays;
  final ToDoItemLocation? location;
  final String? description;
  final bool isCompleted;

  ToDoItem(
      {this.id,
      this.name,
      this.category,
      this.dueDateTimeString,
      this.workDays,
      this.location,
      this.description,
      this.isCompleted = false});

  static ToDoItem? fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return ToDoItem(
        id: JsonUtils.stringValue(json['id']),
        name: JsonUtils.stringValue(json['name']),
        category: ToDoCategory.fromJson(JsonUtils.mapValue(json['category'])),
        dueDateTimeString: JsonUtils.stringValue(json['due_date_time']),
        workDays: JsonUtils.listStringsValue(json['work_days']),
        location: ToDoItemLocation.fromJson(JsonUtils.mapValue(json['location'])),
        description: JsonUtils.stringValue(json['description']),
        isCompleted: JsonUtils.boolValue(json['completed']) ?? false);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category?.toJson(),
      'due_date_time': dueDateTimeString,
      'work_days': workDays,
      'location': location?.toJson(),
      'description': description,
      'completed': isCompleted
    };
  }

  DateTime? get dueDateTime {
    if (StringUtils.isEmpty(dueDateTimeString)) {
      return null;
    }
    return DateTimeUtils.dateTimeFromString(dueDateTimeString, format: _dateTimeFormat);
  }

  String? get displayDueDate {
    if (dueDateTime == null) {
      return null;
    }
    return AppDateTime().formatDateTime(dueDateTime, format: 'EEEE, MM/dd', ignoreTimeZone: true);
  }

  static List<ToDoItem>? listFromJson(List<dynamic>? jsonList) {
    List<ToDoItem>? items;
    if (jsonList != null) {
      items = <ToDoItem>[];
      for (dynamic jsonEntry in jsonList) {
        ListUtils.add(items, ToDoItem.fromJson(jsonEntry));
      }
    }
    return items;
  }
}

class ToDoItemLocation {
  double? latitude;
  double? longitude;

  ToDoItemLocation({this.latitude, this.longitude});

  static ToDoItemLocation? fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return ToDoItemLocation(latitude: JsonUtils.doubleValue(json['latitude']), longitude: JsonUtils.doubleValue(json['longitude']));
  }

  Map<String, dynamic> toJson() {
    return {'latitude': latitude, 'longitude': longitude};
  }
}

class ToDoCategory {
  final String? id;
  final String? name;
  final String? colorHex;
  final ToDoCategoryReminderType? reminderType;

  ToDoCategory({this.id, this.name, this.colorHex, this.reminderType});

  static ToDoCategory? fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return ToDoCategory(
        id: JsonUtils.stringValue(json['id']),
        name: JsonUtils.stringValue(json['name']),
        colorHex: JsonUtils.stringValue(json['color']),
        reminderType: reminderTypeFromString(JsonUtils.stringValue(json['reminder_type'])));
  }

  static List<ToDoCategory>? listFromJson(List<dynamic>? jsonList) {
    List<ToDoCategory>? categories;
    if (jsonList != null) {
      categories = <ToDoCategory>[];
      for (dynamic jsonEntry in jsonList) {
        ListUtils.add(categories, ToDoCategory.fromJson(jsonEntry));
      }
    }
    return categories;
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'color': colorHex, 'reminder_type': reminderTypeToKeyString(reminderType)};
  }

  static ToDoCategoryReminderType? reminderTypeFromString(String? typeValue) {
    switch (typeValue) {
      case 'night_before':
        return ToDoCategoryReminderType.night_before;
      case 'morning_of':
        return ToDoCategoryReminderType.morning_of;
      case 'none':
        return ToDoCategoryReminderType.none;
      default:
        return null;
    }
  }

  static String? reminderTypeToKeyString(ToDoCategoryReminderType? type) {
    switch (type) {
      case ToDoCategoryReminderType.night_before:
        return 'night_before';
      case ToDoCategoryReminderType.morning_of:
        return 'morning_of';
      case ToDoCategoryReminderType.none:
        return 'none';
      default:
        return null;
    }
  }
}

enum ToDoCategoryReminderType { night_before, morning_of, none }
