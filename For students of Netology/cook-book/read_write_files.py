# -*- coding: utf-8 -*-


cook_book = {}

# Чтение файла
with open('recipes.txt', 'r', encoding='utf-8') as file:
    lines = file.readlines()

# Обработка строк
index = 0
while index < len(lines):
    # Получаем название блюда
    dish_name = lines[index].strip()
    index += 1

    # Получаем количество ингредиентов
    num_ingredients = int(lines[index].strip())
    index += 1

    # Список для ингредиентов текущего блюда
    ingredients = []
    for _ in range(num_ingredients):
        ingredient_line = lines[index].strip()
        index += 1

        # Разделяем строку ингредиента на части
        ingredient_name, quantity, measure = ingredient_line.split(' | ')
        ingredients.append({
            'ingredient_name': ingredient_name,
            'quantity': int(quantity),
            'measure': measure
        })

    # Добавляем блюдо в словарь
    cook_book[dish_name] = ingredients

    # Пропускаем пустую строку, если она есть
    if index < len(lines) and lines[index].strip() == '':
        index += 1

# Вывод результата
print(cook_book)
