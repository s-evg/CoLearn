#!/bin/bash
# разворачивает новый микросервис

# Параметры
REPO_URL=$1
PROJECT_DIR="/home/$USER/microservices/$(basename "$REPO_URL" .git)"
ENV_FILE="$PROJECT_DIR/.env"
PROJECT_NAME=$(basename "$PROJECT_DIR")

# Проверка и установка зависимостей, включая python3-venv для нужной версии Python
sudo apt update
sudo apt install -y python3 python3-pip git

# Определение версии Python
PYTHON_VERSION=$(python3 -V 2>&1 | awk '{print $2}' | cut -d. -f1,2)
sudo apt install -y "python${PYTHON_VERSION}-venv"

# Проверка наличия каталога microservices, если нет - создание
if [ ! -d "/home/$USER/microservices" ]; then
  echo "Каталог /home/$USER/microservices не найден, создаём..."
  mkdir -p /home/$USER/microservices
fi

# Клонирование репозитория
if [ ! -d "$PROJECT_DIR" ]; then
  echo "Клонируем репозиторий $REPO_URL в каталог $PROJECT_DIR..."
  git clone "$REPO_URL" "$PROJECT_DIR"
else
  echo "Проект уже существует в $PROJECT_DIR. Пропускаем клонирование."
fi

# Переход в каталог проекта
cd "$PROJECT_DIR" || exit

# Создание виртуального окружения (если его нет)
if [ ! -d "venv" ]; then
  echo "Создаём виртуальное окружение..."
  python3 -m venv venv
fi

# Активируем виртуальное окружение
source venv/bin/activate

# Установка зависимостей
echo "Устанавливаем зависимости из requirements.txt..."
pip install -r requirements.txt

# Запрос на создание .env файла
read -p "Хотите создать файл .env для переменных окружения? (y/n): " create_env
if [ "$create_env" == "y" ]; then
  echo "Открываю файл .env для редактирования..."
  nano "$ENV_FILE"
else
  echo "Вы отклонили создание файла .env."
fi

# Запрос на выбор файла для запуска
echo "Выберите файл для запуска:"
PS3="Введите номер: "
select script_file in *.py; do
  if [[ -n "$script_file" ]]; then
    echo "Вы выбрали файл $script_file для запуска."
    break
  else
    echo "Неверный выбор, попробуйте снова."
  fi
done


# Запрос на создание автозапуска
read -p "Хотите настроить автозапуск после перезагрузки? (y/n): " setup_autostart
if [ "$setup_autostart" == "y" ]; then
  # Создание systemd unit-файла
  echo "Создаём unit-файл для systemd для проекта $PROJECT_NAME..."
  sudo bash -c "cat > /etc/systemd/system/$PROJECT_NAME.service <<EOF
[Unit]
Description=$PROJECT_NAME
After=network.target

[Service]
User=$USER
WorkingDirectory=$PROJECT_DIR
ExecStart=/bin/bash -c 'source $PROJECT_DIR/venv/bin/activate && exec python3 $PROJECT_DIR/$script_file'
Restart=always
EnvironmentFile=$ENV_FILE

[Install]
WantedBy=multi-user.target
EOF"

  # Перезагрузка systemd и активация службы
  sudo systemctl daemon-reload
  sudo systemctl enable "$PROJECT_NAME.service"
  sudo systemctl start "$PROJECT_NAME.service"
  echo "Автозапуск настроен для $PROJECT_NAME."
fi

# Запрос на настройку cron
read -p "Хотите настроить cron-задачу для автоматического обновления? (y/n): " setup_cron
if [ "$setup_cron" == "y" ]; then
  echo "Выберите расписание для cron-задачи:"
  echo "1) Каждые 5 минут"
  echo "2) Каждые 30 минут"
  echo "3) Каждый час в 00 минут"
  echo "4) Каждые 6 часов"
  echo "5) Ежедневно в 6 часов утра и вечера"
  echo "6) Ежедневно в полночь"
  read -p "Введите номер (1-6): " schedule_option
  case $schedule_option in
    1)
      cron_schedule="*/5 * * * *"
      ;;
    2)
      cron_schedule="*/30 * * * *"
      ;;
    3)
      cron_schedule="0 * * * *"
      ;;
    4)
      cron_schedule="0 */6 * * *"
      ;;
    5)
      cron_schedule="0 6,18 * * *"
      ;;
    6)
      cron_schedule="0 0 * * *"
      ;;
    *)
      echo "Неверный выбор. Cron-задача не будет добавлена."
      exit 1
      ;;
  esac

  echo "Добавляем cron-задачу для обновления проекта $PROJECT_NAME..."
  crontab -l > mycron
  echo "$cron_schedule cd $PROJECT_DIR && git fetch && [ \$(git rev-parse HEAD) != \$(git rev-parse @{u}) ] && git pull && sudo systemctl restart $PROJECT_NAME.service >> $PROJECT_DIR/cron_update.log 2>&1" >> mycron
  crontab mycron
  rm mycron
  echo "Cron-задача добавлена для $PROJECT_NAME. Расписание: $cron_schedule."

fi


# Запрос на запуск скрипта
read -p "Хотите сейчас запустить скрипт $script_file? (y/n): " run_script
if [ "$run_script" == "y" ]; then
  echo "Запускаем скрипт $script_file..."
  python3 "$script_file"
else
  echo "Вы не запустили скрипт."
fi


# Принудительная перезагрузка systemd и активация службы
sudo systemctl daemon-reload
sudo systemctl enable "$PROJECT_NAME.service"
sudo systemctl restart "$PROJECT_NAME.service"

echo "Деплой завершён для проекта $PROJECT_NAME."
