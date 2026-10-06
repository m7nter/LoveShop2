import SwiftUI

struct SettingsView: View {
    @ObservedObject private var store = SettingsStore.shared
    @Environment(\.dismiss) var dismiss
    @State private var showPicker = false
    @State private var showChangeMain = false
    @State private var showChangeVault = false
    @State private var showChangeKamikaze = false
    @State private var showActionButtonWarning = false

    var body: some View {
        NavigationView {
            List {
                Section("Фото на снимках") {
                    HStack(spacing: 16) {
                        if let img = store.avatarImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.gray)
                                )
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Button("Выбрать фото") { showPicker = true }
                                .foregroundColor(.orange)
                            if store.avatarImage != nil {
                                Button("Удалить") { store.avatarImage = nil }
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Прицел") {
                    Toggle("Показывать перекрестие", isOn: $store.showCrosshair)
                        .tint(.orange)
                    Toggle("Перекрестие на фото", isOn: $store.crosshairOnPhoto)
                        .tint(.orange)
                    if store.showCrosshair {
                        HStack {
                            Text("Цвет")
                            Spacer()
                            ForEach(["white", "red", "green", "yellow"], id: \.self) { colorName in
                                Circle()
                                    .fill(color(for: colorName))
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Circle().stroke(Color.white,
                                                        lineWidth: store.crosshairColor == colorName ? 2 : 0)
                                    )
                                    .onTapGesture { store.crosshairColor = colorName }
                            }
                        }
                    }
                }

                Section("Точность GPS") {
                    Toggle("Защита от погрешности", isOn: $store.accuracyProtectionEnabled)
                        .tint(.orange)

                    if store.accuracyProtectionEnabled {
                        Picker("Максимальная погрешность", selection: $store.accuracyThreshold) {
                            Text("5 м").tag(5)
                            Text("10 м").tag(10)
                            Text("15 м").tag(15)
                            Text("20 м").tag(20)
                            Text("30 м").tag(30)
                            Text("50 м").tag(50)
                        }
                        Text("Кнопка съёмки будет заблокирована, если погрешность координат превышает выбранное значение")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Дистанция между фото") {
                    Toggle("Показывать дистанцию от последнего фото", isOn: $store.distanceTrackingEnabled)
                        .tint(.orange)

                    if store.distanceTrackingEnabled {
                        Picker("Минимально допустимая дистанция", selection: $store.minDistanceThreshold) {
                            Text("5 м").tag(5)
                            Text("10 м").tag(10)
                            Text("15 м").tag(15)
                            Text("20 м").tag(20)
                            Text("30 м").tag(30)
                            Text("50 м").tag(50)
                            Text("100 м").tag(100)
                        }
                        Text("На экране камеры появится дистанция от последнего сделанного фото. Если она меньше выбранного значения — сработает предупреждение")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Action Button") {
                    Toggle("Быстрый запуск камеры", isOn: Binding(
                        get: { store.actionButtonCameraEnabled },
                        set: { newValue in
                            if newValue {
                                showActionButtonWarning = true
                            } else {
                                store.actionButtonCameraEnabled = false
                            }
                        }
                    ))
                    .tint(.orange)
                    if store.actionButtonCameraEnabled {
                        Text("Функция активна. Камера хранилища открывается через Action Button без пароля.")
                            .font(.caption)
                            .foregroundColor(.red)
                        Text("Как настроить:\n1. Открой приложение «Команды»\n2. Нажми справа вверху + (новая команда)\n3. Нажми «Добавить действие»\n4. В поиске введи «Открыть приложение» и выбери Калькулятор\n5. Добавь действие URL → введи securevault://camera\n6. Добавь ещё одно действие «Открыть URL» следом\n7. Зайди в Настройки → Action Button → Быстрое действие → Команды → выбери эту команду")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("При включении камера хранилища будет доступна через Action Button без ввода пароля.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Съёмка") {
                    Toggle("Снимать кнопками громкости", isOn: $store.volumeButtonCaptureEnabled)
                        .tint(.orange)
                }

                Section("Экспорт фото") {
                    Picker("Способ выгрузки", selection: $store.exportAsZip) {
                        Text("ZIP-архивом").tag(true)
                        Text("Отдельными файлами").tag(false)
                    }
                    .pickerStyle(.segmented)
                    Text(store.exportAsZip
                         ? "Фото за день упаковываются в один ZIP-архив вместе с файлом метаданных (координаты, дата)"
                         : "Каждое фото за день отправляется отдельным файлом без метаданных в архиве")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Карта") {
                    Toggle("Объединять близкие метки", isOn: $store.clusterMapPins)
                        .tint(.orange)
                    Text("Если фото сделаны рядом друг с другом, метки на карте будут объединяться в один кружок с числом снимков. При увеличении масштаба метки разделяются")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Безопасность") {
                    Toggle("Блокировать при сворачивании", isOn: $store.lockOnBackground)
                        .tint(.orange)

                    if !store.lockOnBackground {
                        Picker("Автоблокировка", selection: $store.autoLockTimeout) {
                            Text("Выключено").tag(0)
                            Text("1 минуту").tag(60)
                            Text("5 минут").tag(300)
                            Text("15 минут").tag(900)
                            Text("30 минут").tag(1800)
                        }
                    }

                    Button("Изменить основной пароль") { showChangeMain = true }
                        .foregroundColor(.orange)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Пароль хранилища")
                            Text(store.vaultCodeEnabled ? "Включён" : "Выключен")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { store.vaultCodeEnabled },
                            set: {
                                if $0 && store.vaultCode.isEmpty { showChangeVault = true }
                                else { store.vaultCodeEnabled = $0 }
                            }
                        )).tint(.orange).labelsHidden()
                    }
                    if store.vaultCodeEnabled {
                        Button("Изменить пароль хранилища") { showChangeVault = true }
                            .foregroundColor(.orange)
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Пароль-камикадзе")
                            Text(store.kamikazeCodeEnabled ? "При вводе удалит все фото" : "Выключен")
                                .font(.caption)
                                .foregroundColor(store.kamikazeCodeEnabled ? .red : .secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { store.kamikazeCodeEnabled },
                            set: {
                                if $0 && store.kamikazeCode.isEmpty { showChangeKamikaze = true }
                                else { store.kamikazeCodeEnabled = $0 }
                            }
                        )).tint(.red).labelsHidden()
                    }
                    if store.kamikazeCodeEnabled {
                        Button("Изменить пароль-камикадзе") { showChangeKamikaze = true }
                            .foregroundColor(.red)
                    }
                }

                Section("Подсказка") {
                    Text("Фото отображается в правом нижнем углу каждого снимка")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }.foregroundColor(.orange)
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            ImagePicker { img in store.avatarImage = img }
        }
        .sheet(isPresented: $showChangeMain) {
            ChangeCodeView(title: "Основной пароль", currentCode: store.mainCode, requireCurrent: true) {
                store.mainCode = $0
            }
        }
        .sheet(isPresented: $showChangeVault) {
            ChangeCodeView(title: "Пароль хранилища", currentCode: store.vaultCode, requireCurrent: !store.vaultCode.isEmpty) {
                store.vaultCode = $0
                store.vaultCodeEnabled = true
            }
        }
        .sheet(isPresented: $showChangeKamikaze) {
            ChangeCodeView(title: "Пароль-камикадзе", currentCode: store.kamikazeCode, requireCurrent: !store.kamikazeCode.isEmpty) {
                store.kamikazeCode = $0
                store.kamikazeCodeEnabled = true
            }
        }
        .alert("Внимание: уязвимость безопасности", isPresented: $showActionButtonWarning) {
            Button("Включить", role: .destructive) {
                store.actionButtonCameraEnabled = true
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("При включении этой функции любой человек, у которого окажется твой разблокированный телефон, сможет нажать Action Button и сразу попасть в камеру хранилища без ввода пароля калькулятора.\n\nЭто раскрывает факт существования скрытого хранилища. Снятые фото будут сохранены внутри приложения, но сам вход в камеру останется незащищённым.\n\nВключать только если ты уверен, что телефон не попадёт в чужие руки в разблокированном состоянии.")
        }
    }

    private func color(for name: String) -> Color {
        switch name {
        case "red": return .red
        case "green": return .green
        case "yellow": return .yellow
        default: return .white
        }
    }
}

struct ChangeCodeView: View {
    let title: String
    let currentCode: String
    let requireCurrent: Bool
    let onSave: (String) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var oldCode = ""
    @State private var newCode = ""
    @State private var confirmCode = ""
    @State private var error = ""

    var body: some View {
        NavigationView {
            Form {
                if requireCurrent {
                    Section("Текущий пароль") {
                        SecureField("Введите текущий пароль", text: $oldCode)
                            .keyboardType(.numberPad)
                    }
                }
                Section("Новый пароль") {
                    SecureField("Введите новый пароль", text: $newCode)
                        .keyboardType(.numberPad)
                    SecureField("Повторите новый пароль", text: $confirmCode)
                        .keyboardType(.numberPad)
                }
                if !error.isEmpty {
                    Section {
                        Text(error).foregroundColor(.red).font(.caption)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") { dismiss() }.foregroundColor(.red)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Сохранить") { save() }.foregroundColor(.orange)
                }
            }
        }
    }

    private func save() {
        if requireCurrent && oldCode != currentCode {
            error = "Неверный текущий пароль"; return
        }
        if newCode.count < 4 {
            error = "Пароль должен быть не менее 4 символов"; return
        }
        if newCode != confirmCode {
            error = "Пароли не совпадают"; return
        }
        onSave(newCode)
        dismiss()
    }
}
