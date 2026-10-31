// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $TrackedSendersTable extends TrackedSenders
    with TableInfo<$TrackedSendersTable, TrackedSender> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrackedSendersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _matchPatternMeta = const VerificationMeta(
    'matchPattern',
  );
  @override
  late final GeneratedColumn<String> matchPattern = GeneratedColumn<String>(
    'match_pattern',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Bank, String> bank =
      GeneratedColumn<String>(
        'bank',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Bank>($TrackedSendersTable.$converterbank);
  @override
  List<GeneratedColumn> get $columns => [id, label, matchPattern, bank];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tracked_senders';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrackedSender> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('match_pattern')) {
      context.handle(
        _matchPatternMeta,
        matchPattern.isAcceptableOrUnknown(
          data['match_pattern']!,
          _matchPatternMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_matchPatternMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TrackedSender map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackedSender(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      matchPattern: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}match_pattern'],
      )!,
      bank: $TrackedSendersTable.$converterbank.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}bank'],
        )!,
      ),
    );
  }

  @override
  $TrackedSendersTable createAlias(String alias) {
    return $TrackedSendersTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<Bank, String, String> $converterbank =
      const EnumNameConverter<Bank>(Bank.values);
}

class TrackedSender extends DataClass implements Insertable<TrackedSender> {
  final int id;
  final String label;
  final String matchPattern;
  final Bank bank;
  const TrackedSender({
    required this.id,
    required this.label,
    required this.matchPattern,
    required this.bank,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['label'] = Variable<String>(label);
    map['match_pattern'] = Variable<String>(matchPattern);
    {
      map['bank'] = Variable<String>(
        $TrackedSendersTable.$converterbank.toSql(bank),
      );
    }
    return map;
  }

  TrackedSendersCompanion toCompanion(bool nullToAbsent) {
    return TrackedSendersCompanion(
      id: Value(id),
      label: Value(label),
      matchPattern: Value(matchPattern),
      bank: Value(bank),
    );
  }

  factory TrackedSender.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackedSender(
      id: serializer.fromJson<int>(json['id']),
      label: serializer.fromJson<String>(json['label']),
      matchPattern: serializer.fromJson<String>(json['matchPattern']),
      bank: $TrackedSendersTable.$converterbank.fromJson(
        serializer.fromJson<String>(json['bank']),
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'label': serializer.toJson<String>(label),
      'matchPattern': serializer.toJson<String>(matchPattern),
      'bank': serializer.toJson<String>(
        $TrackedSendersTable.$converterbank.toJson(bank),
      ),
    };
  }

  TrackedSender copyWith({
    int? id,
    String? label,
    String? matchPattern,
    Bank? bank,
  }) => TrackedSender(
    id: id ?? this.id,
    label: label ?? this.label,
    matchPattern: matchPattern ?? this.matchPattern,
    bank: bank ?? this.bank,
  );
  TrackedSender copyWithCompanion(TrackedSendersCompanion data) {
    return TrackedSender(
      id: data.id.present ? data.id.value : this.id,
      label: data.label.present ? data.label.value : this.label,
      matchPattern: data.matchPattern.present
          ? data.matchPattern.value
          : this.matchPattern,
      bank: data.bank.present ? data.bank.value : this.bank,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackedSender(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('matchPattern: $matchPattern, ')
          ..write('bank: $bank')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, label, matchPattern, bank);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackedSender &&
          other.id == this.id &&
          other.label == this.label &&
          other.matchPattern == this.matchPattern &&
          other.bank == this.bank);
}

class TrackedSendersCompanion extends UpdateCompanion<TrackedSender> {
  final Value<int> id;
  final Value<String> label;
  final Value<String> matchPattern;
  final Value<Bank> bank;
  const TrackedSendersCompanion({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.matchPattern = const Value.absent(),
    this.bank = const Value.absent(),
  });
  TrackedSendersCompanion.insert({
    this.id = const Value.absent(),
    required String label,
    required String matchPattern,
    required Bank bank,
  }) : label = Value(label),
       matchPattern = Value(matchPattern),
       bank = Value(bank);
  static Insertable<TrackedSender> custom({
    Expression<int>? id,
    Expression<String>? label,
    Expression<String>? matchPattern,
    Expression<String>? bank,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (label != null) 'label': label,
      if (matchPattern != null) 'match_pattern': matchPattern,
      if (bank != null) 'bank': bank,
    });
  }

  TrackedSendersCompanion copyWith({
    Value<int>? id,
    Value<String>? label,
    Value<String>? matchPattern,
    Value<Bank>? bank,
  }) {
    return TrackedSendersCompanion(
      id: id ?? this.id,
      label: label ?? this.label,
      matchPattern: matchPattern ?? this.matchPattern,
      bank: bank ?? this.bank,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (matchPattern.present) {
      map['match_pattern'] = Variable<String>(matchPattern.value);
    }
    if (bank.present) {
      map['bank'] = Variable<String>(
        $TrackedSendersTable.$converterbank.toSql(bank.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrackedSendersCompanion(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('matchPattern: $matchPattern, ')
          ..write('bank: $bank')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    color,
    icon,
    sortOrder,
    isArchived,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    } else if (isInserting) {
      context.missing(_iconMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final int id;
  final String name;
  final int color;
  final String icon;
  final int sortOrder;
  final bool isArchived;
  const Category({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    required this.sortOrder,
    required this.isArchived,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['color'] = Variable<int>(color);
    map['icon'] = Variable<String>(icon);
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_archived'] = Variable<bool>(isArchived);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      name: Value(name),
      color: Value(color),
      icon: Value(icon),
      sortOrder: Value(sortOrder),
      isArchived: Value(isArchived),
    );
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<int>(json['color']),
      icon: serializer.fromJson<String>(json['icon']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<int>(color),
      'icon': serializer.toJson<String>(icon),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isArchived': serializer.toJson<bool>(isArchived),
    };
  }

  Category copyWith({
    int? id,
    String? name,
    int? color,
    String? icon,
    int? sortOrder,
    bool? isArchived,
  }) => Category(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color ?? this.color,
    icon: icon ?? this.icon,
    sortOrder: sortOrder ?? this.sortOrder,
    isArchived: isArchived ?? this.isArchived,
  );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      icon: data.icon.present ? data.icon.value : this.icon,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('icon: $icon, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isArchived: $isArchived')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, color, icon, sortOrder, isArchived);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.icon == this.icon &&
          other.sortOrder == this.sortOrder &&
          other.isArchived == this.isArchived);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> color;
  final Value<String> icon;
  final Value<int> sortOrder;
  final Value<bool> isArchived;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.icon = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isArchived = const Value.absent(),
  });
  CategoriesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required int color,
    required String icon,
    required int sortOrder,
    this.isArchived = const Value.absent(),
  }) : name = Value(name),
       color = Value(color),
       icon = Value(icon),
       sortOrder = Value(sortOrder);
  static Insertable<Category> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? color,
    Expression<String>? icon,
    Expression<int>? sortOrder,
    Expression<bool>? isArchived,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (icon != null) 'icon': icon,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isArchived != null) 'is_archived': isArchived,
    });
  }

  CategoriesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? color,
    Value<String>? icon,
    Value<int>? sortOrder,
    Value<bool>? isArchived,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('icon: $icon, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isArchived: $isArchived')
          ..write(')'))
        .toString();
  }
}

class $BudgetsTable extends Budgets with TableInfo<$BudgetsTable, Budget> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BudgetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _monthMeta = const VerificationMeta('month');
  @override
  late final GeneratedColumn<String> month = GeneratedColumn<String>(
    'month',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountPaiseMeta = const VerificationMeta(
    'amountPaise',
  );
  @override
  late final GeneratedColumn<int> amountPaise = GeneratedColumn<int>(
    'amount_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, categoryId, month, amountPaise];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'budgets';
  @override
  VerificationContext validateIntegrity(
    Insertable<Budget> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('month')) {
      context.handle(
        _monthMeta,
        month.isAcceptableOrUnknown(data['month']!, _monthMeta),
      );
    }
    if (data.containsKey('amount_paise')) {
      context.handle(
        _amountPaiseMeta,
        amountPaise.isAcceptableOrUnknown(
          data['amount_paise']!,
          _amountPaiseMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountPaiseMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Budget map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Budget(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      )!,
      month: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}month'],
      ),
      amountPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_paise'],
      )!,
    );
  }

  @override
  $BudgetsTable createAlias(String alias) {
    return $BudgetsTable(attachedDatabase, alias);
  }
}

class Budget extends DataClass implements Insertable<Budget> {
  final int id;
  final int categoryId;
  final String? month;
  final int amountPaise;
  const Budget({
    required this.id,
    required this.categoryId,
    this.month,
    required this.amountPaise,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['category_id'] = Variable<int>(categoryId);
    if (!nullToAbsent || month != null) {
      map['month'] = Variable<String>(month);
    }
    map['amount_paise'] = Variable<int>(amountPaise);
    return map;
  }

  BudgetsCompanion toCompanion(bool nullToAbsent) {
    return BudgetsCompanion(
      id: Value(id),
      categoryId: Value(categoryId),
      month: month == null && nullToAbsent
          ? const Value.absent()
          : Value(month),
      amountPaise: Value(amountPaise),
    );
  }

  factory Budget.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Budget(
      id: serializer.fromJson<int>(json['id']),
      categoryId: serializer.fromJson<int>(json['categoryId']),
      month: serializer.fromJson<String?>(json['month']),
      amountPaise: serializer.fromJson<int>(json['amountPaise']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'categoryId': serializer.toJson<int>(categoryId),
      'month': serializer.toJson<String?>(month),
      'amountPaise': serializer.toJson<int>(amountPaise),
    };
  }

  Budget copyWith({
    int? id,
    int? categoryId,
    Value<String?> month = const Value.absent(),
    int? amountPaise,
  }) => Budget(
    id: id ?? this.id,
    categoryId: categoryId ?? this.categoryId,
    month: month.present ? month.value : this.month,
    amountPaise: amountPaise ?? this.amountPaise,
  );
  Budget copyWithCompanion(BudgetsCompanion data) {
    return Budget(
      id: data.id.present ? data.id.value : this.id,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      month: data.month.present ? data.month.value : this.month,
      amountPaise: data.amountPaise.present
          ? data.amountPaise.value
          : this.amountPaise,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Budget(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('month: $month, ')
          ..write('amountPaise: $amountPaise')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, categoryId, month, amountPaise);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Budget &&
          other.id == this.id &&
          other.categoryId == this.categoryId &&
          other.month == this.month &&
          other.amountPaise == this.amountPaise);
}

class BudgetsCompanion extends UpdateCompanion<Budget> {
  final Value<int> id;
  final Value<int> categoryId;
  final Value<String?> month;
  final Value<int> amountPaise;
  const BudgetsCompanion({
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.month = const Value.absent(),
    this.amountPaise = const Value.absent(),
  });
  BudgetsCompanion.insert({
    this.id = const Value.absent(),
    required int categoryId,
    this.month = const Value.absent(),
    required int amountPaise,
  }) : categoryId = Value(categoryId),
       amountPaise = Value(amountPaise);
  static Insertable<Budget> custom({
    Expression<int>? id,
    Expression<int>? categoryId,
    Expression<String>? month,
    Expression<int>? amountPaise,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (categoryId != null) 'category_id': categoryId,
      if (month != null) 'month': month,
      if (amountPaise != null) 'amount_paise': amountPaise,
    });
  }

  BudgetsCompanion copyWith({
    Value<int>? id,
    Value<int>? categoryId,
    Value<String?>? month,
    Value<int>? amountPaise,
  }) {
    return BudgetsCompanion(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      month: month ?? this.month,
      amountPaise: amountPaise ?? this.amountPaise,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (month.present) {
      map['month'] = Variable<String>(month.value);
    }
    if (amountPaise.present) {
      map['amount_paise'] = Variable<int>(amountPaise.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BudgetsCompanion(')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('month: $month, ')
          ..write('amountPaise: $amountPaise')
          ..write(')'))
        .toString();
  }
}

class $SalaryTable extends Salary with TableInfo<$SalaryTable, SalaryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SalaryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _monthMeta = const VerificationMeta('month');
  @override
  late final GeneratedColumn<String> month = GeneratedColumn<String>(
    'month',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountPaiseMeta = const VerificationMeta(
    'amountPaise',
  );
  @override
  late final GeneratedColumn<int> amountPaise = GeneratedColumn<int>(
    'amount_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, month, amountPaise];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'salary';
  @override
  VerificationContext validateIntegrity(
    Insertable<SalaryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('month')) {
      context.handle(
        _monthMeta,
        month.isAcceptableOrUnknown(data['month']!, _monthMeta),
      );
    }
    if (data.containsKey('amount_paise')) {
      context.handle(
        _amountPaiseMeta,
        amountPaise.isAcceptableOrUnknown(
          data['amount_paise']!,
          _amountPaiseMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountPaiseMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SalaryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SalaryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      month: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}month'],
      ),
      amountPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_paise'],
      )!,
    );
  }

  @override
  $SalaryTable createAlias(String alias) {
    return $SalaryTable(attachedDatabase, alias);
  }
}

class SalaryRow extends DataClass implements Insertable<SalaryRow> {
  final int id;
  final String? month;
  final int amountPaise;
  const SalaryRow({required this.id, this.month, required this.amountPaise});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || month != null) {
      map['month'] = Variable<String>(month);
    }
    map['amount_paise'] = Variable<int>(amountPaise);
    return map;
  }

  SalaryCompanion toCompanion(bool nullToAbsent) {
    return SalaryCompanion(
      id: Value(id),
      month: month == null && nullToAbsent
          ? const Value.absent()
          : Value(month),
      amountPaise: Value(amountPaise),
    );
  }

  factory SalaryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SalaryRow(
      id: serializer.fromJson<int>(json['id']),
      month: serializer.fromJson<String?>(json['month']),
      amountPaise: serializer.fromJson<int>(json['amountPaise']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'month': serializer.toJson<String?>(month),
      'amountPaise': serializer.toJson<int>(amountPaise),
    };
  }

  SalaryRow copyWith({
    int? id,
    Value<String?> month = const Value.absent(),
    int? amountPaise,
  }) => SalaryRow(
    id: id ?? this.id,
    month: month.present ? month.value : this.month,
    amountPaise: amountPaise ?? this.amountPaise,
  );
  SalaryRow copyWithCompanion(SalaryCompanion data) {
    return SalaryRow(
      id: data.id.present ? data.id.value : this.id,
      month: data.month.present ? data.month.value : this.month,
      amountPaise: data.amountPaise.present
          ? data.amountPaise.value
          : this.amountPaise,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SalaryRow(')
          ..write('id: $id, ')
          ..write('month: $month, ')
          ..write('amountPaise: $amountPaise')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, month, amountPaise);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SalaryRow &&
          other.id == this.id &&
          other.month == this.month &&
          other.amountPaise == this.amountPaise);
}

class SalaryCompanion extends UpdateCompanion<SalaryRow> {
  final Value<int> id;
  final Value<String?> month;
  final Value<int> amountPaise;
  const SalaryCompanion({
    this.id = const Value.absent(),
    this.month = const Value.absent(),
    this.amountPaise = const Value.absent(),
  });
  SalaryCompanion.insert({
    this.id = const Value.absent(),
    this.month = const Value.absent(),
    required int amountPaise,
  }) : amountPaise = Value(amountPaise);
  static Insertable<SalaryRow> custom({
    Expression<int>? id,
    Expression<String>? month,
    Expression<int>? amountPaise,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (month != null) 'month': month,
      if (amountPaise != null) 'amount_paise': amountPaise,
    });
  }

  SalaryCompanion copyWith({
    Value<int>? id,
    Value<String?>? month,
    Value<int>? amountPaise,
  }) {
    return SalaryCompanion(
      id: id ?? this.id,
      month: month ?? this.month,
      amountPaise: amountPaise ?? this.amountPaise,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (month.present) {
      map['month'] = Variable<String>(month.value);
    }
    if (amountPaise.present) {
      map['amount_paise'] = Variable<int>(amountPaise.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SalaryCompanion(')
          ..write('id: $id, ')
          ..write('month: $month, ')
          ..write('amountPaise: $amountPaise')
          ..write(')'))
        .toString();
  }
}

class $TransactionsTable extends Transactions
    with TableInfo<$TransactionsTable, TransactionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<TransactionType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TransactionType>($TransactionsTable.$convertertype);
  static const VerificationMeta _amountPaiseMeta = const VerificationMeta(
    'amountPaise',
  );
  @override
  late final GeneratedColumn<int> amountPaise = GeneratedColumn<int>(
    'amount_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _counterpartyMeta = const VerificationMeta(
    'counterparty',
  );
  @override
  late final GeneratedColumn<String> counterparty = GeneratedColumn<String>(
    'counterparty',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accountLast4Meta = const VerificationMeta(
    'accountLast4',
  );
  @override
  late final GeneratedColumn<String> accountLast4 = GeneratedColumn<String>(
    'account_last4',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Bank?, String> bank =
      GeneratedColumn<String>(
        'bank',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<Bank?>($TransactionsTable.$converterbankn);
  static const VerificationMeta _refNoMeta = const VerificationMeta('refNo');
  @override
  late final GeneratedColumn<String> refNo = GeneratedColumn<String>(
    'ref_no',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TransactionSource, String>
  source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<TransactionSource>($TransactionsTable.$convertersource);
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rawTextMeta = const VerificationMeta(
    'rawText',
  );
  @override
  late final GeneratedColumn<String> rawText = GeneratedColumn<String>(
    'raw_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    amountPaise,
    occurredAt,
    counterparty,
    accountLast4,
    bank,
    refNo,
    source,
    categoryId,
    note,
    rawText,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<TransactionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('amount_paise')) {
      context.handle(
        _amountPaiseMeta,
        amountPaise.isAcceptableOrUnknown(
          data['amount_paise']!,
          _amountPaiseMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountPaiseMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('counterparty')) {
      context.handle(
        _counterpartyMeta,
        counterparty.isAcceptableOrUnknown(
          data['counterparty']!,
          _counterpartyMeta,
        ),
      );
    }
    if (data.containsKey('account_last4')) {
      context.handle(
        _accountLast4Meta,
        accountLast4.isAcceptableOrUnknown(
          data['account_last4']!,
          _accountLast4Meta,
        ),
      );
    }
    if (data.containsKey('ref_no')) {
      context.handle(
        _refNoMeta,
        refNo.isAcceptableOrUnknown(data['ref_no']!, _refNoMeta),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('raw_text')) {
      context.handle(
        _rawTextMeta,
        rawText.isAcceptableOrUnknown(data['raw_text']!, _rawTextMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TransactionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransactionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      type: $TransactionsTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      amountPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_paise'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      counterparty: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}counterparty'],
      ),
      accountLast4: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_last4'],
      ),
      bank: $TransactionsTable.$converterbankn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}bank'],
        ),
      ),
      refNo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ref_no'],
      ),
      source: $TransactionsTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source'],
        )!,
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      rawText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_text'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TransactionsTable createAlias(String alias) {
    return $TransactionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TransactionType, String, String> $convertertype =
      const EnumNameConverter<TransactionType>(TransactionType.values);
  static JsonTypeConverter2<Bank, String, String> $converterbank =
      const EnumNameConverter<Bank>(Bank.values);
  static JsonTypeConverter2<Bank?, String?, String?> $converterbankn =
      JsonTypeConverter2.asNullable($converterbank);
  static JsonTypeConverter2<TransactionSource, String, String>
  $convertersource = const EnumNameConverter<TransactionSource>(
    TransactionSource.values,
  );
}

class TransactionRow extends DataClass implements Insertable<TransactionRow> {
  final int id;
  final TransactionType type;
  final int amountPaise;
  final DateTime occurredAt;
  final String? counterparty;
  final String? accountLast4;
  final Bank? bank;
  final String? refNo;
  final TransactionSource source;
  final int? categoryId;
  final String? note;
  final String? rawText;
  final DateTime createdAt;
  final DateTime updatedAt;
  const TransactionRow({
    required this.id,
    required this.type,
    required this.amountPaise,
    required this.occurredAt,
    this.counterparty,
    this.accountLast4,
    this.bank,
    this.refNo,
    required this.source,
    this.categoryId,
    this.note,
    this.rawText,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['type'] = Variable<String>(
        $TransactionsTable.$convertertype.toSql(type),
      );
    }
    map['amount_paise'] = Variable<int>(amountPaise);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    if (!nullToAbsent || counterparty != null) {
      map['counterparty'] = Variable<String>(counterparty);
    }
    if (!nullToAbsent || accountLast4 != null) {
      map['account_last4'] = Variable<String>(accountLast4);
    }
    if (!nullToAbsent || bank != null) {
      map['bank'] = Variable<String>(
        $TransactionsTable.$converterbankn.toSql(bank),
      );
    }
    if (!nullToAbsent || refNo != null) {
      map['ref_no'] = Variable<String>(refNo);
    }
    {
      map['source'] = Variable<String>(
        $TransactionsTable.$convertersource.toSql(source),
      );
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || rawText != null) {
      map['raw_text'] = Variable<String>(rawText);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      type: Value(type),
      amountPaise: Value(amountPaise),
      occurredAt: Value(occurredAt),
      counterparty: counterparty == null && nullToAbsent
          ? const Value.absent()
          : Value(counterparty),
      accountLast4: accountLast4 == null && nullToAbsent
          ? const Value.absent()
          : Value(accountLast4),
      bank: bank == null && nullToAbsent ? const Value.absent() : Value(bank),
      refNo: refNo == null && nullToAbsent
          ? const Value.absent()
          : Value(refNo),
      source: Value(source),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      rawText: rawText == null && nullToAbsent
          ? const Value.absent()
          : Value(rawText),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TransactionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransactionRow(
      id: serializer.fromJson<int>(json['id']),
      type: $TransactionsTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      amountPaise: serializer.fromJson<int>(json['amountPaise']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      counterparty: serializer.fromJson<String?>(json['counterparty']),
      accountLast4: serializer.fromJson<String?>(json['accountLast4']),
      bank: $TransactionsTable.$converterbankn.fromJson(
        serializer.fromJson<String?>(json['bank']),
      ),
      refNo: serializer.fromJson<String?>(json['refNo']),
      source: $TransactionsTable.$convertersource.fromJson(
        serializer.fromJson<String>(json['source']),
      ),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
      note: serializer.fromJson<String?>(json['note']),
      rawText: serializer.fromJson<String?>(json['rawText']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'type': serializer.toJson<String>(
        $TransactionsTable.$convertertype.toJson(type),
      ),
      'amountPaise': serializer.toJson<int>(amountPaise),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'counterparty': serializer.toJson<String?>(counterparty),
      'accountLast4': serializer.toJson<String?>(accountLast4),
      'bank': serializer.toJson<String?>(
        $TransactionsTable.$converterbankn.toJson(bank),
      ),
      'refNo': serializer.toJson<String?>(refNo),
      'source': serializer.toJson<String>(
        $TransactionsTable.$convertersource.toJson(source),
      ),
      'categoryId': serializer.toJson<int?>(categoryId),
      'note': serializer.toJson<String?>(note),
      'rawText': serializer.toJson<String?>(rawText),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TransactionRow copyWith({
    int? id,
    TransactionType? type,
    int? amountPaise,
    DateTime? occurredAt,
    Value<String?> counterparty = const Value.absent(),
    Value<String?> accountLast4 = const Value.absent(),
    Value<Bank?> bank = const Value.absent(),
    Value<String?> refNo = const Value.absent(),
    TransactionSource? source,
    Value<int?> categoryId = const Value.absent(),
    Value<String?> note = const Value.absent(),
    Value<String?> rawText = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TransactionRow(
    id: id ?? this.id,
    type: type ?? this.type,
    amountPaise: amountPaise ?? this.amountPaise,
    occurredAt: occurredAt ?? this.occurredAt,
    counterparty: counterparty.present ? counterparty.value : this.counterparty,
    accountLast4: accountLast4.present ? accountLast4.value : this.accountLast4,
    bank: bank.present ? bank.value : this.bank,
    refNo: refNo.present ? refNo.value : this.refNo,
    source: source ?? this.source,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    note: note.present ? note.value : this.note,
    rawText: rawText.present ? rawText.value : this.rawText,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TransactionRow copyWithCompanion(TransactionsCompanion data) {
    return TransactionRow(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      amountPaise: data.amountPaise.present
          ? data.amountPaise.value
          : this.amountPaise,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      counterparty: data.counterparty.present
          ? data.counterparty.value
          : this.counterparty,
      accountLast4: data.accountLast4.present
          ? data.accountLast4.value
          : this.accountLast4,
      bank: data.bank.present ? data.bank.value : this.bank,
      refNo: data.refNo.present ? data.refNo.value : this.refNo,
      source: data.source.present ? data.source.value : this.source,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      note: data.note.present ? data.note.value : this.note,
      rawText: data.rawText.present ? data.rawText.value : this.rawText,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransactionRow(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('amountPaise: $amountPaise, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('counterparty: $counterparty, ')
          ..write('accountLast4: $accountLast4, ')
          ..write('bank: $bank, ')
          ..write('refNo: $refNo, ')
          ..write('source: $source, ')
          ..write('categoryId: $categoryId, ')
          ..write('note: $note, ')
          ..write('rawText: $rawText, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    amountPaise,
    occurredAt,
    counterparty,
    accountLast4,
    bank,
    refNo,
    source,
    categoryId,
    note,
    rawText,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransactionRow &&
          other.id == this.id &&
          other.type == this.type &&
          other.amountPaise == this.amountPaise &&
          other.occurredAt == this.occurredAt &&
          other.counterparty == this.counterparty &&
          other.accountLast4 == this.accountLast4 &&
          other.bank == this.bank &&
          other.refNo == this.refNo &&
          other.source == this.source &&
          other.categoryId == this.categoryId &&
          other.note == this.note &&
          other.rawText == this.rawText &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TransactionsCompanion extends UpdateCompanion<TransactionRow> {
  final Value<int> id;
  final Value<TransactionType> type;
  final Value<int> amountPaise;
  final Value<DateTime> occurredAt;
  final Value<String?> counterparty;
  final Value<String?> accountLast4;
  final Value<Bank?> bank;
  final Value<String?> refNo;
  final Value<TransactionSource> source;
  final Value<int?> categoryId;
  final Value<String?> note;
  final Value<String?> rawText;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const TransactionsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.amountPaise = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.counterparty = const Value.absent(),
    this.accountLast4 = const Value.absent(),
    this.bank = const Value.absent(),
    this.refNo = const Value.absent(),
    this.source = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.note = const Value.absent(),
    this.rawText = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  TransactionsCompanion.insert({
    this.id = const Value.absent(),
    required TransactionType type,
    required int amountPaise,
    required DateTime occurredAt,
    this.counterparty = const Value.absent(),
    this.accountLast4 = const Value.absent(),
    this.bank = const Value.absent(),
    this.refNo = const Value.absent(),
    required TransactionSource source,
    this.categoryId = const Value.absent(),
    this.note = const Value.absent(),
    this.rawText = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : type = Value(type),
       amountPaise = Value(amountPaise),
       occurredAt = Value(occurredAt),
       source = Value(source);
  static Insertable<TransactionRow> custom({
    Expression<int>? id,
    Expression<String>? type,
    Expression<int>? amountPaise,
    Expression<DateTime>? occurredAt,
    Expression<String>? counterparty,
    Expression<String>? accountLast4,
    Expression<String>? bank,
    Expression<String>? refNo,
    Expression<String>? source,
    Expression<int>? categoryId,
    Expression<String>? note,
    Expression<String>? rawText,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (amountPaise != null) 'amount_paise': amountPaise,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (counterparty != null) 'counterparty': counterparty,
      if (accountLast4 != null) 'account_last4': accountLast4,
      if (bank != null) 'bank': bank,
      if (refNo != null) 'ref_no': refNo,
      if (source != null) 'source': source,
      if (categoryId != null) 'category_id': categoryId,
      if (note != null) 'note': note,
      if (rawText != null) 'raw_text': rawText,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  TransactionsCompanion copyWith({
    Value<int>? id,
    Value<TransactionType>? type,
    Value<int>? amountPaise,
    Value<DateTime>? occurredAt,
    Value<String?>? counterparty,
    Value<String?>? accountLast4,
    Value<Bank?>? bank,
    Value<String?>? refNo,
    Value<TransactionSource>? source,
    Value<int?>? categoryId,
    Value<String?>? note,
    Value<String?>? rawText,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return TransactionsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      amountPaise: amountPaise ?? this.amountPaise,
      occurredAt: occurredAt ?? this.occurredAt,
      counterparty: counterparty ?? this.counterparty,
      accountLast4: accountLast4 ?? this.accountLast4,
      bank: bank ?? this.bank,
      refNo: refNo ?? this.refNo,
      source: source ?? this.source,
      categoryId: categoryId ?? this.categoryId,
      note: note ?? this.note,
      rawText: rawText ?? this.rawText,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $TransactionsTable.$convertertype.toSql(type.value),
      );
    }
    if (amountPaise.present) {
      map['amount_paise'] = Variable<int>(amountPaise.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (counterparty.present) {
      map['counterparty'] = Variable<String>(counterparty.value);
    }
    if (accountLast4.present) {
      map['account_last4'] = Variable<String>(accountLast4.value);
    }
    if (bank.present) {
      map['bank'] = Variable<String>(
        $TransactionsTable.$converterbankn.toSql(bank.value),
      );
    }
    if (refNo.present) {
      map['ref_no'] = Variable<String>(refNo.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(
        $TransactionsTable.$convertersource.toSql(source.value),
      );
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rawText.present) {
      map['raw_text'] = Variable<String>(rawText.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('amountPaise: $amountPaise, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('counterparty: $counterparty, ')
          ..write('accountLast4: $accountLast4, ')
          ..write('bank: $bank, ')
          ..write('refNo: $refNo, ')
          ..write('source: $source, ')
          ..write('categoryId: $categoryId, ')
          ..write('note: $note, ')
          ..write('rawText: $rawText, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $IngestLogTable extends IngestLog
    with TableInfo<$IngestLogTable, IngestLogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IngestLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _fingerprintMeta = const VerificationMeta(
    'fingerprint',
  );
  @override
  late final GeneratedColumn<String> fingerprint = GeneratedColumn<String>(
    'fingerprint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _ingestedAtMeta = const VerificationMeta(
    'ingestedAt',
  );
  @override
  late final GeneratedColumn<DateTime> ingestedAt = GeneratedColumn<DateTime>(
    'ingested_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<IngestStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<IngestStatus>($IngestLogTable.$converterstatus);
  static const VerificationMeta _refNoMeta = const VerificationMeta('refNo');
  @override
  late final GeneratedColumn<String> refNo = GeneratedColumn<String>(
    'ref_no',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rawTextMeta = const VerificationMeta(
    'rawText',
  );
  @override
  late final GeneratedColumn<String> rawText = GeneratedColumn<String>(
    'raw_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fingerprint,
    ingestedAt,
    status,
    refNo,
    rawText,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ingest_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<IngestLogRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('fingerprint')) {
      context.handle(
        _fingerprintMeta,
        fingerprint.isAcceptableOrUnknown(
          data['fingerprint']!,
          _fingerprintMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fingerprintMeta);
    }
    if (data.containsKey('ingested_at')) {
      context.handle(
        _ingestedAtMeta,
        ingestedAt.isAcceptableOrUnknown(data['ingested_at']!, _ingestedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_ingestedAtMeta);
    }
    if (data.containsKey('ref_no')) {
      context.handle(
        _refNoMeta,
        refNo.isAcceptableOrUnknown(data['ref_no']!, _refNoMeta),
      );
    }
    if (data.containsKey('raw_text')) {
      context.handle(
        _rawTextMeta,
        rawText.isAcceptableOrUnknown(data['raw_text']!, _rawTextMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  IngestLogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IngestLogRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      fingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fingerprint'],
      )!,
      ingestedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ingested_at'],
      )!,
      status: $IngestLogTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      refNo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ref_no'],
      ),
      rawText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_text'],
      ),
    );
  }

  @override
  $IngestLogTable createAlias(String alias) {
    return $IngestLogTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<IngestStatus, String, String> $converterstatus =
      const EnumNameConverter<IngestStatus>(IngestStatus.values);
}

class IngestLogRow extends DataClass implements Insertable<IngestLogRow> {
  final int id;
  final String fingerprint;
  final DateTime ingestedAt;
  final IngestStatus status;
  final String? refNo;
  final String? rawText;
  const IngestLogRow({
    required this.id,
    required this.fingerprint,
    required this.ingestedAt,
    required this.status,
    this.refNo,
    this.rawText,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['fingerprint'] = Variable<String>(fingerprint);
    map['ingested_at'] = Variable<DateTime>(ingestedAt);
    {
      map['status'] = Variable<String>(
        $IngestLogTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || refNo != null) {
      map['ref_no'] = Variable<String>(refNo);
    }
    if (!nullToAbsent || rawText != null) {
      map['raw_text'] = Variable<String>(rawText);
    }
    return map;
  }

  IngestLogCompanion toCompanion(bool nullToAbsent) {
    return IngestLogCompanion(
      id: Value(id),
      fingerprint: Value(fingerprint),
      ingestedAt: Value(ingestedAt),
      status: Value(status),
      refNo: refNo == null && nullToAbsent
          ? const Value.absent()
          : Value(refNo),
      rawText: rawText == null && nullToAbsent
          ? const Value.absent()
          : Value(rawText),
    );
  }

  factory IngestLogRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IngestLogRow(
      id: serializer.fromJson<int>(json['id']),
      fingerprint: serializer.fromJson<String>(json['fingerprint']),
      ingestedAt: serializer.fromJson<DateTime>(json['ingestedAt']),
      status: $IngestLogTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      refNo: serializer.fromJson<String?>(json['refNo']),
      rawText: serializer.fromJson<String?>(json['rawText']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'fingerprint': serializer.toJson<String>(fingerprint),
      'ingestedAt': serializer.toJson<DateTime>(ingestedAt),
      'status': serializer.toJson<String>(
        $IngestLogTable.$converterstatus.toJson(status),
      ),
      'refNo': serializer.toJson<String?>(refNo),
      'rawText': serializer.toJson<String?>(rawText),
    };
  }

  IngestLogRow copyWith({
    int? id,
    String? fingerprint,
    DateTime? ingestedAt,
    IngestStatus? status,
    Value<String?> refNo = const Value.absent(),
    Value<String?> rawText = const Value.absent(),
  }) => IngestLogRow(
    id: id ?? this.id,
    fingerprint: fingerprint ?? this.fingerprint,
    ingestedAt: ingestedAt ?? this.ingestedAt,
    status: status ?? this.status,
    refNo: refNo.present ? refNo.value : this.refNo,
    rawText: rawText.present ? rawText.value : this.rawText,
  );
  IngestLogRow copyWithCompanion(IngestLogCompanion data) {
    return IngestLogRow(
      id: data.id.present ? data.id.value : this.id,
      fingerprint: data.fingerprint.present
          ? data.fingerprint.value
          : this.fingerprint,
      ingestedAt: data.ingestedAt.present
          ? data.ingestedAt.value
          : this.ingestedAt,
      status: data.status.present ? data.status.value : this.status,
      refNo: data.refNo.present ? data.refNo.value : this.refNo,
      rawText: data.rawText.present ? data.rawText.value : this.rawText,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IngestLogRow(')
          ..write('id: $id, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('ingestedAt: $ingestedAt, ')
          ..write('status: $status, ')
          ..write('refNo: $refNo, ')
          ..write('rawText: $rawText')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, fingerprint, ingestedAt, status, refNo, rawText);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IngestLogRow &&
          other.id == this.id &&
          other.fingerprint == this.fingerprint &&
          other.ingestedAt == this.ingestedAt &&
          other.status == this.status &&
          other.refNo == this.refNo &&
          other.rawText == this.rawText);
}

class IngestLogCompanion extends UpdateCompanion<IngestLogRow> {
  final Value<int> id;
  final Value<String> fingerprint;
  final Value<DateTime> ingestedAt;
  final Value<IngestStatus> status;
  final Value<String?> refNo;
  final Value<String?> rawText;
  const IngestLogCompanion({
    this.id = const Value.absent(),
    this.fingerprint = const Value.absent(),
    this.ingestedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.refNo = const Value.absent(),
    this.rawText = const Value.absent(),
  });
  IngestLogCompanion.insert({
    this.id = const Value.absent(),
    required String fingerprint,
    required DateTime ingestedAt,
    required IngestStatus status,
    this.refNo = const Value.absent(),
    this.rawText = const Value.absent(),
  }) : fingerprint = Value(fingerprint),
       ingestedAt = Value(ingestedAt),
       status = Value(status);
  static Insertable<IngestLogRow> custom({
    Expression<int>? id,
    Expression<String>? fingerprint,
    Expression<DateTime>? ingestedAt,
    Expression<String>? status,
    Expression<String>? refNo,
    Expression<String>? rawText,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (ingestedAt != null) 'ingested_at': ingestedAt,
      if (status != null) 'status': status,
      if (refNo != null) 'ref_no': refNo,
      if (rawText != null) 'raw_text': rawText,
    });
  }

  IngestLogCompanion copyWith({
    Value<int>? id,
    Value<String>? fingerprint,
    Value<DateTime>? ingestedAt,
    Value<IngestStatus>? status,
    Value<String?>? refNo,
    Value<String?>? rawText,
  }) {
    return IngestLogCompanion(
      id: id ?? this.id,
      fingerprint: fingerprint ?? this.fingerprint,
      ingestedAt: ingestedAt ?? this.ingestedAt,
      status: status ?? this.status,
      refNo: refNo ?? this.refNo,
      rawText: rawText ?? this.rawText,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (fingerprint.present) {
      map['fingerprint'] = Variable<String>(fingerprint.value);
    }
    if (ingestedAt.present) {
      map['ingested_at'] = Variable<DateTime>(ingestedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $IngestLogTable.$converterstatus.toSql(status.value),
      );
    }
    if (refNo.present) {
      map['ref_no'] = Variable<String>(refNo.value);
    }
    if (rawText.present) {
      map['raw_text'] = Variable<String>(rawText.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IngestLogCompanion(')
          ..write('id: $id, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('ingestedAt: $ingestedAt, ')
          ..write('status: $status, ')
          ..write('refNo: $refNo, ')
          ..write('rawText: $rawText')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TrackedSendersTable trackedSenders = $TrackedSendersTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $BudgetsTable budgets = $BudgetsTable(this);
  late final $SalaryTable salary = $SalaryTable(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $IngestLogTable ingestLog = $IngestLogTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final Index budgetsCategoryMonth = Index(
    'budgets_category_month',
    'CREATE UNIQUE INDEX budgets_category_month ON budgets (category_id, COALESCE(month, \'\'))',
  );
  late final Index salaryMonth = Index(
    'salary_month',
    'CREATE UNIQUE INDEX salary_month ON salary (COALESCE(month, \'\'))',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    trackedSenders,
    categories,
    budgets,
    salary,
    transactions,
    ingestLog,
    settings,
    budgetsCategoryMonth,
    salaryMonth,
  ];
}

typedef $$TrackedSendersTableCreateCompanionBuilder =
    TrackedSendersCompanion Function({
      Value<int> id,
      required String label,
      required String matchPattern,
      required Bank bank,
    });
typedef $$TrackedSendersTableUpdateCompanionBuilder =
    TrackedSendersCompanion Function({
      Value<int> id,
      Value<String> label,
      Value<String> matchPattern,
      Value<Bank> bank,
    });

class $$TrackedSendersTableFilterComposer
    extends Composer<_$AppDatabase, $TrackedSendersTable> {
  $$TrackedSendersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get matchPattern => $composableBuilder(
    column: $table.matchPattern,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Bank, Bank, String> get bank =>
      $composableBuilder(
        column: $table.bank,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$TrackedSendersTableOrderingComposer
    extends Composer<_$AppDatabase, $TrackedSendersTable> {
  $$TrackedSendersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get matchPattern => $composableBuilder(
    column: $table.matchPattern,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bank => $composableBuilder(
    column: $table.bank,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TrackedSendersTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrackedSendersTable> {
  $$TrackedSendersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get matchPattern => $composableBuilder(
    column: $table.matchPattern,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Bank, String> get bank =>
      $composableBuilder(column: $table.bank, builder: (column) => column);
}

class $$TrackedSendersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TrackedSendersTable,
          TrackedSender,
          $$TrackedSendersTableFilterComposer,
          $$TrackedSendersTableOrderingComposer,
          $$TrackedSendersTableAnnotationComposer,
          $$TrackedSendersTableCreateCompanionBuilder,
          $$TrackedSendersTableUpdateCompanionBuilder,
          (
            TrackedSender,
            BaseReferences<_$AppDatabase, $TrackedSendersTable, TrackedSender>,
          ),
          TrackedSender,
          PrefetchHooks Function()
        > {
  $$TrackedSendersTableTableManager(
    _$AppDatabase db,
    $TrackedSendersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrackedSendersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrackedSendersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrackedSendersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String> matchPattern = const Value.absent(),
                Value<Bank> bank = const Value.absent(),
              }) => TrackedSendersCompanion(
                id: id,
                label: label,
                matchPattern: matchPattern,
                bank: bank,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String label,
                required String matchPattern,
                required Bank bank,
              }) => TrackedSendersCompanion.insert(
                id: id,
                label: label,
                matchPattern: matchPattern,
                bank: bank,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TrackedSendersTable, TrackedSender>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $TrackedSendersTable,
                    TrackedSender
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TrackedSendersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TrackedSendersTable,
      TrackedSender,
      $$TrackedSendersTableFilterComposer,
      $$TrackedSendersTableOrderingComposer,
      $$TrackedSendersTableAnnotationComposer,
      $$TrackedSendersTableCreateCompanionBuilder,
      $$TrackedSendersTableUpdateCompanionBuilder,
      (
        TrackedSender,
        BaseReferences<_$AppDatabase, $TrackedSendersTable, TrackedSender>,
      ),
      TrackedSender,
      PrefetchHooks Function()
    >;
typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  Value<int> id,
  required String name,
  required int color,
  required String icon,
  required int sortOrder,
  Value<bool> isArchived,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<int> color,
  Value<String> icon,
  Value<int> sortOrder,
  Value<bool> isArchived,
});

final class $$CategoriesTableReferences
    extends BaseReferences<_$AppDatabase, $CategoriesTable, Category> {
  $$CategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$BudgetsTable, List<Budget>> _budgetsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.budgets,
    aliasName: 'categories__id__budgets__category_id',
  );

  $$BudgetsTableProcessedTableManager get budgetsRefs {
    final manager = $$BudgetsTableTableManager(
      $_db,
      $_db.budgets,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_budgetsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TransactionsTable, List<TransactionRow>>
  _transactionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transactions,
    aliasName: 'categories__id__transactions__category_id',
  );

  $$TransactionsTableProcessedTableManager get transactionsRefs {
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_transactionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> budgetsRefs(
    Expression<bool> Function($$BudgetsTableFilterComposer f) f,
  ) {
    final $$BudgetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.budgets,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BudgetsTableFilterComposer(
            $db: $db,
            $table: $db.budgets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> transactionsRefs(
    Expression<bool> Function($$TransactionsTableFilterComposer f) f,
  ) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  Expression<T> budgetsRefs<T extends Object>(
    Expression<T> Function($$BudgetsTableAnnotationComposer a) f,
  ) {
    final $$BudgetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.budgets,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BudgetsTableAnnotationComposer(
            $db: $db,
            $table: $db.budgets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> transactionsRefs<T extends Object>(
    Expression<T> Function($$TransactionsTableAnnotationComposer a) f,
  ) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (Category, $$CategoriesTableReferences),
          Category,
          PrefetchHooks Function({bool budgetsRefs, bool transactionsRefs})
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                name: name,
                color: color,
                icon: icon,
                sortOrder: sortOrder,
                isArchived: isArchived,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required int color,
                required String icon,
                required int sortOrder,
                Value<bool> isArchived = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                name: name,
                color: color,
                icon: icon,
                sortOrder: sortOrder,
                isArchived: isArchived,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoriesTable, Category>(table),
                  $$CategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({budgetsRefs = false, transactionsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (budgetsRefs) db.budgets,
                    if (transactionsRefs) db.transactions,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (budgetsRefs)
                        await $_getPrefetchedDataByColumns<
                          Category,
                          $CategoriesTable,
                          Budget,
                          $BudgetsTable
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._budgetsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).budgetsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'category_id',
                          typedResults: items,
                        ),
                      if (transactionsRefs)
                        await $_getPrefetchedDataByColumns<
                          Category,
                          $CategoriesTable,
                          TransactionRow,
                          $TransactionsTable
                        >(
                          currentTable: table,
                          referencedTable: $$CategoriesTableReferences
                              ._transactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).transactionsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'category_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, $$CategoriesTableReferences),
      Category,
      PrefetchHooks Function({bool budgetsRefs, bool transactionsRefs})
    >;
typedef $$BudgetsTableCreateCompanionBuilder = BudgetsCompanion Function({
  Value<int> id,
  required int categoryId,
  Value<String?> month,
  required int amountPaise,
});
typedef $$BudgetsTableUpdateCompanionBuilder = BudgetsCompanion Function({
  Value<int> id,
  Value<int> categoryId,
  Value<String?> month,
  Value<int> amountPaise,
});

final class $$BudgetsTableReferences
    extends BaseReferences<_$AppDatabase, $BudgetsTable, Budget> {
  $$BudgetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias('budgets__category_id__categories__id');

  $$CategoriesTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<int>('category_id')!;

    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BudgetsTableFilterComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BudgetsTableOrderingComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BudgetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get month =>
      $composableBuilder(column: $table.month, builder: (column) => column);

  GeneratedColumn<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => column,
  );

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BudgetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BudgetsTable,
          Budget,
          $$BudgetsTableFilterComposer,
          $$BudgetsTableOrderingComposer,
          $$BudgetsTableAnnotationComposer,
          $$BudgetsTableCreateCompanionBuilder,
          $$BudgetsTableUpdateCompanionBuilder,
          (Budget, $$BudgetsTableReferences),
          Budget,
          PrefetchHooks Function({bool categoryId})
        > {
  $$BudgetsTableTableManager(_$AppDatabase db, $BudgetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BudgetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BudgetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BudgetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> categoryId = const Value.absent(),
                Value<String?> month = const Value.absent(),
                Value<int> amountPaise = const Value.absent(),
              }) => BudgetsCompanion(
                id: id,
                categoryId: categoryId,
                month: month,
                amountPaise: amountPaise,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int categoryId,
                Value<String?> month = const Value.absent(),
                required int amountPaise,
              }) => BudgetsCompanion.insert(
                id: id,
                categoryId: categoryId,
                month: month,
                amountPaise: amountPaise,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BudgetsTable, Budget>(table),
                  $$BudgetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (categoryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.categoryId,
                        referencedTable: $$BudgetsTableReferences
                            ._categoryIdTable(db),
                        referencedColumn: $$BudgetsTableReferences
                            ._categoryIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BudgetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BudgetsTable,
      Budget,
      $$BudgetsTableFilterComposer,
      $$BudgetsTableOrderingComposer,
      $$BudgetsTableAnnotationComposer,
      $$BudgetsTableCreateCompanionBuilder,
      $$BudgetsTableUpdateCompanionBuilder,
      (Budget, $$BudgetsTableReferences),
      Budget,
      PrefetchHooks Function({bool categoryId})
    >;
typedef $$SalaryTableCreateCompanionBuilder = SalaryCompanion Function({
  Value<int> id,
  Value<String?> month,
  required int amountPaise,
});
typedef $$SalaryTableUpdateCompanionBuilder = SalaryCompanion Function({
  Value<int> id,
  Value<String?> month,
  Value<int> amountPaise,
});

class $$SalaryTableFilterComposer
    extends Composer<_$AppDatabase, $SalaryTable> {
  $$SalaryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SalaryTableOrderingComposer
    extends Composer<_$AppDatabase, $SalaryTable> {
  $$SalaryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SalaryTableAnnotationComposer
    extends Composer<_$AppDatabase, $SalaryTable> {
  $$SalaryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get month =>
      $composableBuilder(column: $table.month, builder: (column) => column);

  GeneratedColumn<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => column,
  );
}

class $$SalaryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SalaryTable,
          SalaryRow,
          $$SalaryTableFilterComposer,
          $$SalaryTableOrderingComposer,
          $$SalaryTableAnnotationComposer,
          $$SalaryTableCreateCompanionBuilder,
          $$SalaryTableUpdateCompanionBuilder,
          (SalaryRow, BaseReferences<_$AppDatabase, $SalaryTable, SalaryRow>),
          SalaryRow,
          PrefetchHooks Function()
        > {
  $$SalaryTableTableManager(_$AppDatabase db, $SalaryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SalaryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SalaryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SalaryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> month = const Value.absent(),
            Value<int> amountPaise = const Value.absent(),
          }) => SalaryCompanion(id: id, month: month, amountPaise: amountPaise),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> month = const Value.absent(),
                required int amountPaise,
              }) => SalaryCompanion.insert(
                id: id,
                month: month,
                amountPaise: amountPaise,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SalaryTable, SalaryRow>(table),
                  BaseReferences<_$AppDatabase, $SalaryTable, SalaryRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SalaryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SalaryTable,
      SalaryRow,
      $$SalaryTableFilterComposer,
      $$SalaryTableOrderingComposer,
      $$SalaryTableAnnotationComposer,
      $$SalaryTableCreateCompanionBuilder,
      $$SalaryTableUpdateCompanionBuilder,
      (SalaryRow, BaseReferences<_$AppDatabase, $SalaryTable, SalaryRow>),
      SalaryRow,
      PrefetchHooks Function()
    >;
typedef $$TransactionsTableCreateCompanionBuilder =
    TransactionsCompanion Function({
      Value<int> id,
      required TransactionType type,
      required int amountPaise,
      required DateTime occurredAt,
      Value<String?> counterparty,
      Value<String?> accountLast4,
      Value<Bank?> bank,
      Value<String?> refNo,
      required TransactionSource source,
      Value<int?> categoryId,
      Value<String?> note,
      Value<String?> rawText,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$TransactionsTableUpdateCompanionBuilder =
    TransactionsCompanion Function({
      Value<int> id,
      Value<TransactionType> type,
      Value<int> amountPaise,
      Value<DateTime> occurredAt,
      Value<String?> counterparty,
      Value<String?> accountLast4,
      Value<Bank?> bank,
      Value<String?> refNo,
      Value<TransactionSource> source,
      Value<int?> categoryId,
      Value<String?> note,
      Value<String?> rawText,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$TransactionsTableReferences
    extends BaseReferences<_$AppDatabase, $TransactionsTable, TransactionRow> {
  $$TransactionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias('transactions__category_id__categories__id');

  $$CategoriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<int>('category_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TransactionType, TransactionType, String>
  get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get counterparty => $composableBuilder(
    column: $table.counterparty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountLast4 => $composableBuilder(
    column: $table.accountLast4,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Bank?, Bank, String> get bank =>
      $composableBuilder(
        column: $table.bank,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get refNo => $composableBuilder(
    column: $table.refNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TransactionSource, TransactionSource, String>
  get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawText => $composableBuilder(
    column: $table.rawText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get counterparty => $composableBuilder(
    column: $table.counterparty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountLast4 => $composableBuilder(
    column: $table.accountLast4,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bank => $composableBuilder(
    column: $table.bank,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get refNo => $composableBuilder(
    column: $table.refNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawText => $composableBuilder(
    column: $table.rawText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TransactionType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get counterparty => $composableBuilder(
    column: $table.counterparty,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accountLast4 => $composableBuilder(
    column: $table.accountLast4,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Bank?, String> get bank =>
      $composableBuilder(column: $table.bank, builder: (column) => column);

  GeneratedColumn<String> get refNo =>
      $composableBuilder(column: $table.refNo, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TransactionSource, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get rawText =>
      $composableBuilder(column: $table.rawText, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransactionsTable,
          TransactionRow,
          $$TransactionsTableFilterComposer,
          $$TransactionsTableOrderingComposer,
          $$TransactionsTableAnnotationComposer,
          $$TransactionsTableCreateCompanionBuilder,
          $$TransactionsTableUpdateCompanionBuilder,
          (TransactionRow, $$TransactionsTableReferences),
          TransactionRow,
          PrefetchHooks Function({bool categoryId})
        > {
  $$TransactionsTableTableManager(_$AppDatabase db, $TransactionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<TransactionType> type = const Value.absent(),
                Value<int> amountPaise = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<String?> counterparty = const Value.absent(),
                Value<String?> accountLast4 = const Value.absent(),
                Value<Bank?> bank = const Value.absent(),
                Value<String?> refNo = const Value.absent(),
                Value<TransactionSource> source = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> rawText = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TransactionsCompanion(
                id: id,
                type: type,
                amountPaise: amountPaise,
                occurredAt: occurredAt,
                counterparty: counterparty,
                accountLast4: accountLast4,
                bank: bank,
                refNo: refNo,
                source: source,
                categoryId: categoryId,
                note: note,
                rawText: rawText,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required TransactionType type,
                required int amountPaise,
                required DateTime occurredAt,
                Value<String?> counterparty = const Value.absent(),
                Value<String?> accountLast4 = const Value.absent(),
                Value<Bank?> bank = const Value.absent(),
                Value<String?> refNo = const Value.absent(),
                required TransactionSource source,
                Value<int?> categoryId = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> rawText = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TransactionsCompanion.insert(
                id: id,
                type: type,
                amountPaise: amountPaise,
                occurredAt: occurredAt,
                counterparty: counterparty,
                accountLast4: accountLast4,
                bank: bank,
                refNo: refNo,
                source: source,
                categoryId: categoryId,
                note: note,
                rawText: rawText,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TransactionsTable, TransactionRow>(table),
                  $$TransactionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (categoryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.categoryId,
                        referencedTable: $$TransactionsTableReferences
                            ._categoryIdTable(db),
                        referencedColumn: $$TransactionsTableReferences
                            ._categoryIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransactionsTable,
      TransactionRow,
      $$TransactionsTableFilterComposer,
      $$TransactionsTableOrderingComposer,
      $$TransactionsTableAnnotationComposer,
      $$TransactionsTableCreateCompanionBuilder,
      $$TransactionsTableUpdateCompanionBuilder,
      (TransactionRow, $$TransactionsTableReferences),
      TransactionRow,
      PrefetchHooks Function({bool categoryId})
    >;
typedef $$IngestLogTableCreateCompanionBuilder = IngestLogCompanion Function({
  Value<int> id,
  required String fingerprint,
  required DateTime ingestedAt,
  required IngestStatus status,
  Value<String?> refNo,
  Value<String?> rawText,
});
typedef $$IngestLogTableUpdateCompanionBuilder = IngestLogCompanion Function({
  Value<int> id,
  Value<String> fingerprint,
  Value<DateTime> ingestedAt,
  Value<IngestStatus> status,
  Value<String?> refNo,
  Value<String?> rawText,
});

class $$IngestLogTableFilterComposer
    extends Composer<_$AppDatabase, $IngestLogTable> {
  $$IngestLogTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get ingestedAt => $composableBuilder(
    column: $table.ingestedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<IngestStatus, IngestStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get refNo => $composableBuilder(
    column: $table.refNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawText => $composableBuilder(
    column: $table.rawText,
    builder: (column) => ColumnFilters(column),
  );
}

class $$IngestLogTableOrderingComposer
    extends Composer<_$AppDatabase, $IngestLogTable> {
  $$IngestLogTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get ingestedAt => $composableBuilder(
    column: $table.ingestedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get refNo => $composableBuilder(
    column: $table.refNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawText => $composableBuilder(
    column: $table.rawText,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IngestLogTableAnnotationComposer
    extends Composer<_$AppDatabase, $IngestLogTable> {
  $$IngestLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get ingestedAt => $composableBuilder(
    column: $table.ingestedAt,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<IngestStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get refNo =>
      $composableBuilder(column: $table.refNo, builder: (column) => column);

  GeneratedColumn<String> get rawText =>
      $composableBuilder(column: $table.rawText, builder: (column) => column);
}

class $$IngestLogTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $IngestLogTable,
          IngestLogRow,
          $$IngestLogTableFilterComposer,
          $$IngestLogTableOrderingComposer,
          $$IngestLogTableAnnotationComposer,
          $$IngestLogTableCreateCompanionBuilder,
          $$IngestLogTableUpdateCompanionBuilder,
          (
            IngestLogRow,
            BaseReferences<_$AppDatabase, $IngestLogTable, IngestLogRow>,
          ),
          IngestLogRow,
          PrefetchHooks Function()
        > {
  $$IngestLogTableTableManager(_$AppDatabase db, $IngestLogTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IngestLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IngestLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IngestLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> fingerprint = const Value.absent(),
                Value<DateTime> ingestedAt = const Value.absent(),
                Value<IngestStatus> status = const Value.absent(),
                Value<String?> refNo = const Value.absent(),
                Value<String?> rawText = const Value.absent(),
              }) => IngestLogCompanion(
                id: id,
                fingerprint: fingerprint,
                ingestedAt: ingestedAt,
                status: status,
                refNo: refNo,
                rawText: rawText,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String fingerprint,
                required DateTime ingestedAt,
                required IngestStatus status,
                Value<String?> refNo = const Value.absent(),
                Value<String?> rawText = const Value.absent(),
              }) => IngestLogCompanion.insert(
                id: id,
                fingerprint: fingerprint,
                ingestedAt: ingestedAt,
                status: status,
                refNo: refNo,
                rawText: rawText,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$IngestLogTable, IngestLogRow>(table),
                  BaseReferences<_$AppDatabase, $IngestLogTable, IngestLogRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$IngestLogTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $IngestLogTable,
      IngestLogRow,
      $$IngestLogTableFilterComposer,
      $$IngestLogTableOrderingComposer,
      $$IngestLogTableAnnotationComposer,
      $$IngestLogTableCreateCompanionBuilder,
      $$IngestLogTableUpdateCompanionBuilder,
      (
        IngestLogRow,
        BaseReferences<_$AppDatabase, $IngestLogTable, IngestLogRow>,
      ),
      IngestLogRow,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, Setting>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, Setting>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TrackedSendersTableTableManager get trackedSenders =>
      $$TrackedSendersTableTableManager(_db, _db.trackedSenders);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$BudgetsTableTableManager get budgets =>
      $$BudgetsTableTableManager(_db, _db.budgets);
  $$SalaryTableTableManager get salary =>
      $$SalaryTableTableManager(_db, _db.salary);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db, _db.transactions);
  $$IngestLogTableTableManager get ingestLog =>
      $$IngestLogTableTableManager(_db, _db.ingestLog);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
