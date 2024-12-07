:- use_module(library(readutil)). % Модуль для чтения файлов
:- use_module(library(apply)).    % Модуль для применения предикатов к спискам
:- use_module(library(lists)).    % Модуль для работы со списками

:- object(report_generator).
    :- public(start/0).

    % Основной метод для запуска программы
    start :-
        write('Reading employee data from file...'), nl,
        load_employee_data('employees.csv', Employees),
        write('Employee data loaded.'), nl,
		write('Generating TeX file:'), nl,
        generate_report(Employees, 'report.tex'),
        convert_to_pdf('report'),
        write('Report generated successfully!'), nl.

    % Предикат для загрузки данных из CSV файла
    :- private(load_employee_data/2).
    load_employee_data(File, Employees) :-
        open(File, read, Stream),
        read_lines(Stream, Lines),
        close(Stream),
        parse_csv(Lines, Employees).

    % Чтение строк из файла
    :- private(read_lines/2).
    read_lines(Stream, []) :-
        at_end_of_stream(Stream), !.
    read_lines(Stream, [Line|Lines]) :-
        readutil:read_line_to_string(Stream, Line),
        read_lines(Stream, Lines).

    % Парсинг CSV
    :- private(parse_csv/2).
    parse_csv([_|DataLines], Employees) :- % Пропускаем первую строку (заголовок)
        apply:maplist(parse_line, DataLines, Employees).

    parse_line(Line, employee(Name, Age, Position)) :-
        split_string(Line, ",", "", [Name, AgeStr, Position]),
        number_string(Age, AgeStr).

    %-- Генерация отчёта в формате LaTeX --
	:- private(generate_report/2).

	% Генерация отчёта
	generate_report(Employees, File) :-
		open(File, write, Stream),
		
		% Преамбула LuaLaTeX
		write(Stream, '\\documentclass{article}\n'),
		write(Stream, '\\usepackage{fontspec}\n'),             
		write(Stream, '\\setmainfont{Times New Roman}\n'),  
		write(Stream, '\\usepackage[russian]{babel}\n'),    % Поддержка русского языка
		write(Stream, '\\usepackage{geometry}\n'),         
		write(Stream, '\\usepackage{graphicx}\n'),         
		write(Stream, '\\usepackage{longtable}\n'),       
		write(Stream, '\\usepackage{setspace}\n'),
		write(Stream, '\\geometry{a4paper, margin=1in}\n'),
		write(Stream, '\\pagestyle{empty}\n'),
		write(Stream, '\\fontsize{14}{17}\\selectfont\n'),  % Размер шрифта: 14
		write(Stream, '\\onehalfspacing\n'),  				% Межстрочный интервал: 1.5
		write(Stream, '\\begin{document}\n'),
		
		% Для каждого сотрудника генерируем отдельный документ
		forall(
			lists:member(employee(Name, Age, Position), Employees),
			(
				% Логотип
				write(Stream, '\\begin{center}\n'),
				write(Stream, '\\includegraphics[width=0.25\\textwidth]{leti-logo.png}\n'),
				write(Stream, '\\vspace{0.5cm}\n'),
			
				% Текст после логотипа
				write(Stream, '\\\\МИНОБРНАУКИ РОССИИ\\\\\n'),
				write(Stream, 'федеральное государственное автономное образовательное учреждение высшего образования\\\\\n'),
				write(Stream, '{\\textbf{«Санкт-Петербургский государственный электротехнический университет \\\\ ЛЭТИ им. В.И. Ульянова (Ленина)»}}\\\\\n'), % Жирный текст
				write(Stream, '\\textbf{(СПбГЭТУ «ЛЭТИ»)}\n'),
				write(Stream, '\\end{center}\n'),
				write(Stream, '\\vspace{1cm}\n'),
				
				% Дата
				write(Stream, 'Дата: \\today\n'),
				write(Stream, '\\vspace{1cm}\n'),

				% Текст справки с подставленными значениями
				write(Stream, '\\\\ Настоящий документ является подтверждением того, что \\textbf{'),
				write(Stream, Name), write(Stream, '} занимает должность \\textbf{'),
				write(Stream, Position), write(Stream, '} в учреждении \\textbf{«Санкт-Петербургский государственный электротехнический университет ЛЭТИ им. В.И. Ульянова (Ленина)»}.\n'),
				write(Stream, '\\vspace{1cm}\n'),
				
				% Многостраничная таблица с рабочим составом
				write(Stream, '\\section*{Полный рабочий состав}\n'),
				write(Stream, '\\begin{longtable}{|p{0.03\\textwidth}|p{0.38\\textwidth}|p{0.09\\textwidth}|p{0.40\\textwidth}|}\n'),
				write(Stream, '\\hline\n'),
				write(Stream, '\\textbf{№} & \\textbf{Имя} & \\textbf{Возраст} & \\textbf{Должность} \\\\\n'), % Заголовки жирным
				write(Stream, '\\hline\n'),
				write(Stream, '\\endfirsthead\n'), % Заголовок для первой страницы таблицы
				write(Stream, '\\hline\n'),
				write(Stream, '\\textbf{№} & \\textbf{Имя} & \\textbf{Возраст} & \\textbf{Должность} \\\\\n'), % Заголовки жирным
				write(Stream, '\\hline\n'),
				write(Stream, '\\endhead\n'), % Заголовок для последующих страниц таблицы
				generate_employee_table(Employees, Stream, 1),
				write(Stream, '\\end{longtable}\n'),
				
				% Выводим общее количество сотрудников
				length(Employees, EmployeeCount),
				format(Stream, 'Общее количество сотрудников: ~d\n', [EmployeeCount]),
				write(Stream, '\\vspace{1cm}\n'),
				
				% Подпись ректора
				write(Stream, '\\\\ \\vspace{1cm}\n'),
				write(Stream, '\\begin{tabular}{@{}p{0.5\\textwidth}@{}p{0.49\\textwidth}@{}}\n'),
				write(Stream, '\\textbf{Ректор} & \\hfill \\textbf{И. О. Фамилия} \\\\\n'),
				write(Stream, '\\hline\n'),
				write(Stream, '\\end{tabular}\n'),
				write(Stream, '\\vspace{1cm}\n'),
				
				write(Stream, '\\newpage\n')
			)
		),
		write(Stream, '\\end{document}\n'),
		close(Stream).

	% Генерация таблицы с сотрудниками
	generate_employee_table([], _, _).
	generate_employee_table([employee(Name, Age, Position) | Rest], Stream, Index) :-
		% Записываем данные текущего сотрудника
		format(Stream, '~d & ~w & ~d & ~w \\\\\\hline\n', [Index, Name, Age, Position]),
		% Инкрементируем индекс и делаем рекурсивный вызов функции для оставшихся сотрудников
		NewIndex is Index + 1,
		generate_employee_table(Rest, Stream, NewIndex).


    % Конвертация LaTeX в PDF
    :- private(convert_to_pdf/1).
    convert_to_pdf(FileBaseName) :-
		format(atom(Command), 'lualatex ~w.tex', [FileBaseName]),
		format('Executing: ~w~n', [Command]),
		(   shell(Command, ExitCode),
			ExitCode =:= 0
		->  write('PDF generated successfully!'), nl
		;   write('Error during PDF generation'), nl
		),
		cleanup_temp_files(FileBaseName).

    % Удаление временных файлов после конвертации
    :- private(cleanup_temp_files/1).
    cleanup_temp_files(FileBaseName) :-
        format(atom(AuxFile), '~w.aux', [FileBaseName]),
        format(atom(LogFile), '~w.log', [FileBaseName]),
        format(atom(TocFile), '~w.toc', [FileBaseName]),
        catch(delete_file(AuxFile), _, true),
        catch(delete_file(LogFile), _, true),
        catch(delete_file(TocFile), _, true).

:- end_object.

% Запуск программы
:- initialization((
    report_generator::start
)).
