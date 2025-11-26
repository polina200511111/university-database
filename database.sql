-- =============================================
-- БАЗА ДАННЫХ "УНИВЕРСИТЕТ" 
-- =============================================

-- Таблица факультетов
CREATE TABLE faculties (
    faculty_id SERIAL PRIMARY KEY,
    faculty_name VARCHAR(100) NOT NULL UNIQUE,
    dean_name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица студентов
CREATE TABLE students (
    student_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE,
    faculty_id INTEGER NOT NULL REFERENCES faculties(faculty_id),
    enrollment_year INTEGER NOT NULL CHECK (enrollment_year >= 2000 AND enrollment_year <= 2024),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица курсов
CREATE TABLE courses (
    course_id SERIAL PRIMARY KEY,
    course_name VARCHAR(100) NOT NULL,
    description TEXT,
    credits INTEGER NOT NULL CHECK (credits BETWEEN 1 AND 10),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица оценок
CREATE TABLE grades (
    grade_id SERIAL PRIMARY KEY,
    student_id INTEGER NOT NULL REFERENCES students(student_id),
    course_id INTEGER NOT NULL REFERENCES courses(course_id),
    grade INTEGER NOT NULL CHECK (grade >= 1 AND grade <= 5),
    exam_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- ИНДЕКСЫ ДЛЯ ПРОИЗВОДИТЕЛЬНОСТИ
-- =============================================

CREATE INDEX idx_students_faculty ON students(faculty_id);
CREATE INDEX idx_grades_student ON grades(student_id);
CREATE INDEX idx_grades_course ON grades(course_id);
CREATE INDEX idx_grades_date ON grades(exam_date);
CREATE INDEX idx_students_name ON students(last_name, first_name);

-- =============================================
-- ТРИГГЕРЫ
-- =============================================

-- Триггер для проверки email студента
CREATE OR REPLACE FUNCTION validate_student_email()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.email IS NOT NULL AND NEW.email !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
        RAISE EXCEPTION 'Invalid email format';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_validate_email
    BEFORE INSERT OR UPDATE ON students
    FOR EACH ROW EXECUTE FUNCTION validate_student_email();

-- =============================================
-- АВТОМАТИЧЕСКОЕ ЗАПОЛНЕНИЕ СЛУЧАЙНЫМИ ДАННЫМИ
-- =============================================

-- Функция для генерации случайных данных
CREATE OR REPLACE FUNCTION generate_sample_data()
RETURNS VOID AS $$
DECLARE
    i INTEGER;
    faculty_count INTEGER;
    course_count INTEGER;
BEGIN
    -- Очистка таблиц
    TRUNCATE TABLE grades, students, courses, faculties RESTART IDENTITY CASCADE;
    
    -- Факультеты
    INSERT INTO faculties (faculty_name, dean_name) VALUES 
    ('Факультет информатики', 'Иванов А.С.'),
    ('Факультет экономики', 'Петрова М.И.'),
    ('Факультет лингвистики', 'Сидорова О.П.'),
    ('Факультет математики', 'Козлов Д.В.');
    
    -- Курсы
    INSERT INTO courses (course_name, description, credits) VALUES
    ('Базы данных', 'Основы проектирования и работы с БД', 5),
    ('Веб-программирование', 'Создание веб-приложений', 4),
    ('Экономика', 'Экономическая теория', 3),
    ('Иностранный язык', 'Английский для IT-специалистов', 2),
    ('Математический анализ', 'Дифференциальное и интегральное исчисление', 6),
    ('Теория вероятностей', 'Вероятностные модели и статистика', 4),
    ('Операционные системы', 'Архитектура и принципы ОС', 5);
    
    -- Студенты (50 случайных)
    FOR i IN 1..50 LOOP
        INSERT INTO students (first_name, last_name, email, faculty_id, enrollment_year)
        VALUES (
            'Студент' || i,
            'Фамилия' || i,
            'student' || i || '@edu.ru',
            (random() * 3 + 1)::INTEGER,
            (2020 + (random() * 4))::INTEGER
        );
    END LOOP;
    
    -- Оценки (200 случайных)
    FOR i IN 1..200 LOOP
        INSERT INTO grades (student_id, course_id, grade, exam_date)
        VALUES (
            (random() * 49 + 1)::INTEGER,
            (random() * 6 + 1)::INTEGER,
            (random() * 4 + 1)::INTEGER,
            DATE '2024-01-01' + (random() * 300)::INTEGER
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Вызов функции для заполнения данными
SELECT generate_sample_data();

-- =============================================
-- ПРИМЕРЫ ЗАПРОСОВ С ОПИСАНИЕМ
-- =============================================

-- 1. СРЕДНИЙ БАЛЛ ПО ФАКУЛЬТЕТАМ (GROUP BY)
-- Описание: Группирует студентов по факультетам и вычисляет средний балл
SELECT 
    f.faculty_name,
    ROUND(AVG(g.grade), 2) as average_grade,
    COUNT(DISTINCT s.student_id) as student_count
FROM faculties f
JOIN students s ON f.faculty_id = s.faculty_id
JOIN grades g ON s.student_id = g.student_id
GROUP BY f.faculty_id, f.faculty_name
ORDER BY average_grade DESC;

-- 2. СТУДЕНТЫ С ВЫСОКИМ СРЕДНИМ БАЛЛОМ (WHERE + GROUP BY)
-- Описание: Находит студентов со средним баллом выше 4.0
SELECT 
    s.first_name,
    s.last_name,
    f.faculty_name,
    ROUND(AVG(g.grade), 2) as average_grade,
    COUNT(g.grade_id) as exams_count
FROM students s
JOIN faculties f ON s.faculty_id = f.faculty_id
JOIN grades g ON s.student_id = g.student_id
GROUP BY s.student_id, s.first_name, s.last_name, f.faculty_name
HAVING AVG(g.grade) > 4.0
ORDER BY average_grade DESC;

-- 3. САМЫЕ ПОПУЛЯРНЫЕ КУРСЫ (GROUP BY + COUNT)
-- Описание: Показывает курсы с наибольшим количеством оценок
SELECT 
    c.course_name,
    COUNT(g.grade_id) as grades_count,
    ROUND(AVG(g.grade), 2) as average_grade
FROM courses c
LEFT JOIN grades g ON c.course_id = g.course_id
GROUP BY c.course_id, c.course_name
ORDER BY grades_count DESC;

-- =============================================
-- ТЕСТ ПРОИЗВОДИТЕЛЬНОСТИ
-- =============================================

-- Анализ производительности запроса
EXPLAIN ANALYZE 
SELECT s.first_name, s.last_name, c.course_name, g.grade
FROM grades g
JOIN students s ON g.student_id = s.student_id
JOIN courses c ON g.course_id = c.course_id
WHERE g.grade = 5
ORDER BY g.exam_date DESC
LIMIT 100;