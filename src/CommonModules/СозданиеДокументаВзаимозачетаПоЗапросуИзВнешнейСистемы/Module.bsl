////////////////////////////////////////////////////////////////////////////////
// МОДУЛЬ : СозданиеДокументаВзаимозачетаПоЗапросуИзВнешнейСистемы
//
// - ФТ звучит так - клиент заявляет, что мы ему что-то должны, т.е. возник аванс клиента у нас
// - У рядовых менеджеров нет доступа к платёжной информации и они не работают в 1С
// - В процедуры библиотеки обмена попадает значение булево какой-то переменной и вызывается эта процедура
// - Код запроса взят из типового интерфейсного функционала и переделан под автоматическое создание документа взаимозачета
// - Так, чтобы все имеющиеся свободные авансы клиента были перенесены в новый заказ
// - Дальнейшая синхронизация по платёжной информации происходит в модуле объект этого документа
//
//
////////////////////////////////////////////////////////////////////////////////

#Область СлужебныеПроцедурыИФункции

Процедура ВыгрузитьАвансВCRM(Знач Заказ,Знач АйдиЗаказа,Знач КодМагазина) 	
  	Запрос = Новый Запрос;////
	МенеджерВременныхТаблиц = Новый МенеджерВременныхТаблиц;
	Запрос.МенеджерВременныхТаблиц = МенеджерВременныхТаблиц;
	Договор = Справочники.ДоговорыКонтрагентов.ПустаяСсылка();
	РеквизитыЗаказа = ОбщегоНазначения.ЗначенияРеквизитовОбъекта(Заказ,"НомерПоДаннымКлиента,ОбъектРасчетов,Контрагент,Организация,Партнер,Дата,Валюта,Объект");
	Организации = Новый СписокЗначений();
	ДоступныеПартнеры = Новый СписокЗначений;
	ДоступныеПартнеры.Добавить(РеквизитыЗаказа.Партнер);
	
	РасшифровкаПлатежа = Новый ТаблицаЗначений();
	РасшифровкаПлатежа.Колонки.Добавить("ОбъектРасчетов",Новый ОписаниеТипов("СправочникСсылка.ОбъектыРасчетов"));
	РасшифровкаПлатежа.Колонки.Добавить("Валюта",Новый ОписаниеТипов("СправочникСсылка.Валюты" ));
	РасшифровкаПлатежа.Колонки.Добавить("Договор",Новый ОписаниеТипов("СправочникСсылка.ДоговорыКонтрагентов" ));
	РасшифровкаПлатежа.Колонки.Добавить("Контрагент",Новый ОписаниеТипов("СправочникСсылка.Контрагенты" ));
	РасшифровкаПлатежа.Колонки.Добавить("Организация",Новый ОписаниеТипов("СправочникСсылка.Организации" ));
	РасшифровкаПлатежа.Колонки.Добавить("Партнер",Новый ОписаниеТипов("СправочникСсылка.Партнеры" ));
	РасшифровкаПлатежа.Колонки.Добавить("Сумма",Новый ОписаниеТипов("Число" ));
	РасшифровкаПлатежа.Колонки.Добавить("СуммаВзаиморасчетов",Новый ОписаниеТипов("Число" ));
	СписокОбъектов = Новый СписокЗначений(); 
	
	Запрос.УстановитьПараметр("Договор",                      Договор);	
	Запрос.УстановитьПараметр("ОбъектРасчетов",               РеквизитыЗаказа.ОбъектРасчетов); 
	Запрос.УстановитьПараметр("Организация",   Организации  ); 
	Запрос.УстановитьПараметр("ЭтоУправленческаяОрганизация", Ложь);
	Запрос.УстановитьПараметр("Партнер",                      РеквизитыЗаказа.Партнер);
	Запрос.УстановитьПараметр("ДоступныеПартнеры",            ДоступныеПартнеры);
	Запрос.УстановитьПараметр("Контрагент", РеквизитыЗаказа.Контрагент);
	Запрос.УстановитьПараметр("РасшифровкаПлатежа",           РасшифровкаПлатежа);
	Запрос.УстановитьПараметр("ОбъектРасчетовНакладная",      Ложь);
	Запрос.УстановитьПараметр("ЗачетСЗаказовДоговора",Ложь);
	Запрос.УстановитьПараметр("ДатаДокумента",              НачалоДня(РеквизитыЗаказа.Дата));
	Запрос.УстановитьПараметр("ПартнерДокумента",             РеквизитыЗаказа.Партнер);
	Запрос.УстановитьПараметр("НаправлениеДеятельности",      Справочники.НаправленияДеятельности.ПустаяСсылка());
	Запрос.УстановитьПараметр("ВалютаВзаиморасчетов",         РеквизитыЗаказа.Валюта);
	Запрос.УстановитьПараметр("ВалютаРеглУчета",              РеквизитыЗаказа.Валюта);
	Запрос.УстановитьПараметр("СписокОбъектов",               СписокОбъектов); 
	Запрос.УстановитьПараметр("ТекущийМесяц",                 НачалоМесяца(ТекущаяДатаСеанса()));
	Запрос.УстановитьПараметр("НоваяАрхитектураВзаиморасчетов",      Истина);
	ТекстЗапроса = "
	|ВЫБРАТЬ
	|	АналитикаПоПартнерам.КлючАналитики КАК КлючАналитики,
	|	АналитикаПоПартнерам.Партнер КАК Партнер,
	|	АналитикаПоПартнерам.Организация КАК Организация,
	|	АналитикаПоПартнерам.Контрагент КАК Контрагент,
	|	АналитикаПоПартнерам.Договор КАК Договор
	|
	|ПОМЕСТИТЬ АналитикаУчетаПоПартнерам
	|ИЗ
	|	РегистрСведений.АналитикаУчетаПоПартнерам КАК АналитикаПоПартнерам
	|ГДЕ
	|	(АналитикаПоПартнерам.Организация В (&Организация) И НЕ &ЭтоУправленческаяОрганизация
	|		ИЛИ &ЭтоУправленческаяОрганизация И АналитикаПоПартнерам.Организация <> ЗНАЧЕНИЕ(Справочник.Организации.УправленческаяОрганизация))
	|	И (АналитикаПоПартнерам.Партнер В (&Партнер)
	|		ИЛИ АналитикаПоПартнерам.Партнер В (&ДоступныеПартнеры) И ЕСТЬNULL(АналитикаПоПартнерам.Договор.РазрешенаРаботаСДочернимиПартнерами, ИСТИНА))
	|	И АналитикаПоПартнерам.Контрагент = &Контрагент
	|;
	|////////////////////////////////////////////////////////////////////////////////
	|ВЫБРАТЬ РАЗЛИЧНЫЕ
	|	ТаблицаРасшифровкаПлатежаНакладная.Партнер        КАК Партнер,
	|	ТаблицаРасшифровкаПлатежаНакладная.ОбъектРасчетов КАК ОбъектРасчетов,
	|	ТаблицаРасшифровкаПлатежаНакладная.Контрагент     КАК Контрагент,
	|	ТаблицаРасшифровкаПлатежаНакладная.Договор        КАК Договор,
	|	ТаблицаРасшифровкаПлатежаНакладная.Организация    КАК Организация,
	|	ТаблицаРасшифровкаПлатежаНакладная.Валюта         КАК Валюта,
	|	ТаблицаРасшифровкаПлатежаНакладная.Сумма          КАК Сумма,
	|	ТаблицаРасшифровкаПлатежаНакладная.СуммаВзаиморасчетов КАК СуммаВзаиморасчетов
	|ПОМЕСТИТЬ ТаблицаРасшифровкаПлатежаНакладная
	|ИЗ &РасшифровкаПлатежа КАК ТаблицаРасшифровкаПлатежаНакладная
	|;";
	ТекстЗапроса2 = "
	|ВЫБРАТЬ
	|	РасчетыСКлиентами.ОбъектРасчетов                             КАК ОбъектРасчетов,
	|	РасчетыСКлиентами.Валюта                                     КАК ВалютаВзаиморасчетов,
	|	ОбъектыРасчетов.Объект                                       КАК Документ,
	|	РасчетыСКлиентами.АналитикаУчетаПоПартнерам                  КАК КлючАналитики,
	|	ОбъектыРасчетов.Организация                                  КАК Организация,
	|	ОбъектыРасчетов.Партнер                                      КАК Партнер,
	|	ОбъектыРасчетов.Контрагент                                   КАК Контрагент,
	|	ОбъектыРасчетов.Дата                                         КАК Дата,
	|	ОбъектыРасчетов.Сумма                                        КАК СуммаДокумента,
	|	ОбъектыРасчетов.Валюта                                       КАК Валюта,
	|	-РасчетыСКлиентами.СуммаОстаток - ЕСТЬNULL(Расшифровка.Сумма,0) КАК ДоступноКЗачету,
	|	ВЫБОР КОГДА ОбъектыРасчетов.Сумма <> 0 И ОбъектыРасчетов.СуммаВзаиморасчетов <> 0
	|		ТОГДА -(РасчетыСКлиентами.СуммаОстаток - ЕСТЬNULL(Расшифровка.Сумма,0)) * ОбъектыРасчетов.СуммаВзаиморасчетов/ОбъектыРасчетов.Сумма
	|		ИНАЧЕ -РасчетыСКлиентами.СуммаОстаток - ЕСТЬNULL(Расшифровка.Сумма,0)
	|	КОНЕЦ                                                        КАК СуммаВВалютеПлатежа,
	|	ИСТИНА                                                       КАК ДоступноРедактирование,
	|	&ОбъектРасчетовНакладная
	|		И (&ЗачетСЗаказовДоговора 
	|				И (ОбъектыРасчетов.ТипОбъектаРасчетов = ЗНАЧЕНИЕ(Перечисление.ТипыОбъектовРасчетов.Заказ)
	|					ИЛИ ОбъектыРасчетов.ТипОбъектаРасчетов = ЗНАЧЕНИЕ(Перечисление.ТипыОбъектовРасчетов.Договор))
	|			ИЛИ (ОбъектыРасчетов.ТипОбъектаРасчетов = ЗНАЧЕНИЕ(Перечисление.ТипыОбъектовРасчетов.ПлатежВозврат)
	|					И НАЧАЛОПЕРИОДА(ОбъектыРасчетов.Дата,ДЕНЬ) < &ДатаДокумента))    КАК РасшифровкаОбъектаРасчетов
	|ПОМЕСТИТЬ ВтНераспределенныеПлатежи
	|ИЗ
	|	РегистрНакопления.РасчетыСКлиентами.Остатки(,
	|		АналитикаУчетаПоПартнерам В (
	|			ВЫБРАТЬ
	|				АналитикаПоПартнерам.КлючАналитики КАК КлючАналитики
	|			ИЗ
	|				АналитикаУчетаПоПартнерам КАК АналитикаПоПартнерам
	|			)
	|	) КАК РасчетыСКлиентами
	|	
	|	ВНУТРЕННЕЕ СОЕДИНЕНИЕ
	|		Справочник.ОбъектыРасчетов КАК ОбъектыРасчетов
	|	ПО
	|		ОбъектыРасчетов.Ссылка = РасчетыСКлиентами.ОбъектРасчетов
	|	ЛЕВОЕ СОЕДИНЕНИЕ ТаблицаРасшифровкаПлатежаНакладная КАК Расшифровка
	|		ПО Расшифровка.ОбъектРасчетов = РасчетыСКлиентами.ОбъектРасчетов
	|	
	|ГДЕ
	|	НЕ &ЭтоУправленческаяОрганизация
	|	И (ОбъектыРасчетов.Договор = &Договор
	|		ИЛИ НЕ (ОбъектыРасчетов.Дата < &ДатаДокумента И &ОбъектРасчетовНакладная )
	|				И ОбъектыРасчетов.Договор В (ЗНАЧЕНИЕ(Справочник.ДоговорыКонтрагентов.ПустаяСсылка)
	|												,ЗНАЧЕНИЕ(Справочник.ДоговорыМеждуОрганизациями.ПустаяСсылка)))
	|	И РасчетыСКлиентами.АналитикаУчетаПоПартнерам.Партнер = &ПартнерДокумента
	|	И ОбъектыРасчетов.НаправлениеДеятельности = &НаправлениеДеятельности
	|	И ОбъектыРасчетов.ВалютаВзаиморасчетов = &ВалютаВзаиморасчетов
	|	И РасчетыСКлиентами.СуммаОстаток < 0
	|	И НЕ ОбъектыРасчетов.Объект ССЫЛКА Документ.ПервичныйДокумент
	|	И (&ОбъектРасчетовНакладная
	|			И (ОбъектыРасчетов.ТипОбъектаРасчетов = ЗНАЧЕНИЕ(Перечисление.ТипыОбъектовРасчетов.ПлатежВозврат)
	|				ИЛИ ОбъектыРасчетов.Объект В (&СписокОбъектов)
	|						И (ОбъектыРасчетов.ТипОбъектаРасчетов = ЗНАЧЕНИЕ(Перечисление.ТипыОбъектовРасчетов.Заказ)
	|							ИЛИ ОбъектыРасчетов.ТипОбъектаРасчетов = ЗНАЧЕНИЕ(Перечисление.ТипыОбъектовРасчетов.Договор))
	|					)
	|		ИЛИ НЕ &ОбъектРасчетовНакладная
	|			И &ДатаДокумента < НАЧАЛОПЕРИОДА(ОбъектыРасчетов.Дата,ДЕНЬ)
	|			И ОбъектыРасчетов.ТипОбъектаРасчетов = ЗНАЧЕНИЕ(Перечисление.ТипыОбъектовРасчетов.ПлатежВозврат))
	|
	|ОБЪЕДИНИТЬ ВСЕ
	|
	|ВЫБРАТЬ
	|	РасчетыСКлиентами.ОбъектРасчетов                             КАК ОбъектРасчетов,
	|	РасчетыСКлиентами.Валюта                                     КАК ВалютаВзаиморасчетов,
	|	ОбъектыРасчетов.Объект                                       КАК Документ,
	|	РасчетыСКлиентами.АналитикаУчетаПоПартнерам                  КАК КлючАналитики,
	|	ОбъектыРасчетов.Организация                                  КАК Организация,
	|	ОбъектыРасчетов.Партнер                                      КАК Партнер,
	|	ОбъектыРасчетов.Контрагент                                   КАК Контрагент,
	|	ОбъектыРасчетов.Дата                                         КАК Дата,
	|	ОбъектыРасчетов.Сумма                                        КАК СуммаДокумента,
	|	ОбъектыРасчетов.Валюта                                       КАК Валюта,
	|	РасчетыСКлиентами.СуммаРасход                                КАК ДоступноКЗачету,
	|	ОбъектыРасчетов.СуммаВзаиморасчетов                          КАК СуммаВВалютеПлатежа,
	|	ИСТИНА                                                       КАК ДоступноРедактирование,
	|	ИСТИНА                                                       КАК РасшифровкаОбъектаРасчетов
	|ИЗ
	|	РегистрНакопления.РасчетыСКлиентами.ОстаткиИОбороты(,,,,
	|		АналитикаУчетаПоПартнерам В (
	|			ВЫБРАТЬ
	|				АналитикаПоПартнерам.КлючАналитики КАК КлючАналитики
	|			ИЗ
	|				АналитикаУчетаПоПартнерам КАК АналитикаПоПартнерам
	|			)) КАК РасчетыСКлиентами
	|	
	|	ВНУТРЕННЕЕ СОЕДИНЕНИЕ
	|		Справочник.ОбъектыРасчетов КАК ОбъектыРасчетов
	|	ПО
	|		ОбъектыРасчетов.Ссылка = РасчетыСКлиентами.ОбъектРасчетов
	|	
	|	ЛЕВОЕ СОЕДИНЕНИЕ Документ.РеализацияТоваровУслуг.РасшифровкаПлатежа КАК Расшифровка
	|		ПО Расшифровка.ОбъектРасчетов =  &ОбъектРасчетов
	|			И Расшифровка.Ссылка = ОбъектыРасчетов.Объект
	|
	|ГДЕ
	|	&ЭтоУправленческаяОрганизация
	|	И НЕ ОбъектыРасчетов.Организация В (&Организация)
	|	И ОбъектыРасчетов.Валюта = &ВалютаВзаиморасчетов
	|	И ОбъектыРасчетов.Партнер = &ПартнерДокумента
	|	И ОбъектыРасчетов.Объект ССЫЛКА Документ.РеализацияТоваровУслуг
	|	И ВЫРАЗИТЬ(ОбъектыРасчетов.Объект КАК Документ.РеализацияТоваровУслуг).ХозяйственнаяОперация = ЗНАЧЕНИЕ(Перечисление.ХозяйственныеОперации.РеализацияКлиентуРеглУчет)
	|	И РасчетыСКлиентами.СуммаРасход > 0 
	|	И РасчетыСКлиентами.СуммаКонечныйОстаток = 0
	|	И Расшифровка.ОбъектРасчетов ЕСТЬ NULL
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	// Зачтено упр и регл
	|ВЫБРАТЬ
	|	РасчетыПоДокументам.Регистратор КАК Регистратор,
	|	СУММА(РасчетыПоДокументам.ПредоплатаРегл + РасчетыПоДокументам.ДолгРегл) КАК СуммаРегл,
	|	СУММА(РасчетыПоДокументам.ПредоплатаУпр + РасчетыПоДокументам.ДолгУпр) КАК СуммаУпр
	|ПОМЕСТИТЬ РаспределенныеРасчеты
	|ИЗ
	|	РегистрНакопления.РасчетыСКлиентамиПоДокументам КАК РасчетыПоДокументам
	|ГДЕ
	|	НЕ &НоваяАрхитектураВзаиморасчетов
	|	И РасчетыПоДокументам.АналитикаУчетаПоПартнерам В (ВЫБРАТЬ КлючАналитики ИЗ АналитикаУчетаПоПартнерам)
	|	И &ОбъектРасчетов = РасчетыПоДокументам.ЗаказКлиента
	|	И РасчетыПоДокументам.Активность
	|СГРУППИРОВАТЬ ПО
	|	РасчетыПоДокументам.Регистратор
	|	
	|ОБЪЕДИНИТЬ ВСЕ
	|	
	//расчеты по накладным
	|ВЫБРАТЬ
	|	РасчетыПоСрокам.КорОбъектРасчетов.Объект КАК Регистратор,
	|	СУММА(РасчетыПоСрокам.ПредоплатаРегл) КАК СуммаРегл,
	|	СУММА(РасчетыПоСрокам.ПредоплатаУпр) КАК СуммаУпр
	|ИЗ
	|	РегистрНакопления.РасчетыСКлиентамиПоСрокам КАК РасчетыПоСрокам
	|ГДЕ
	|	&НоваяАрхитектураВзаиморасчетов
	|	И РасчетыПоСрокам.АналитикаУчетаПоПартнерам В (ВЫБРАТЬ КлючАналитики ИЗ АналитикаУчетаПоПартнерам)
	|	И &ОбъектРасчетов = РасчетыПоСрокам.ОбъектРасчетов
	|	И РасчетыПоСрокам.Активность
	|	И РасчетыПоСрокам.Предоплата <> 0 
	|	И РасчетыПоСрокам.ВидДвижения = ЗНАЧЕНИЕ(ВидДвиженияНакопления.Расход) 
	|	И РасчетыПоСрокам.КорОбъектРасчетов <> Неопределено
	|	И НЕ РасчетыПоСрокам.ДокументРегистратор ССЫЛКА Документ.ВзаимозачетЗадолженности
	|СГРУППИРОВАТЬ ПО
	|	РасчетыПоСрокам.КорОбъектРасчетов 
	|	
	|	ОБЪЕДИНИТЬ ВСЕ
	|	
	//расчеты не по накладным
	|ВЫБРАТЬ
	|	РасчетыПоСрокам.ДокументРегистратор КАК Регистратор,
	|	СУММА(РасчетыПоСрокам.ПредоплатаРегл + РасчетыПоСрокам.ДолгРегл) КАК СуммаРегл,
	|	СУММА(РасчетыПоСрокам.ПредоплатаУпр + РасчетыПоСрокам.ДолгУпр) КАК СуммаУпр
	|ИЗ
	|	РегистрНакопления.РасчетыСКлиентамиПоСрокам КАК РасчетыПоСрокам
	|ГДЕ
	|	&НоваяАрхитектураВзаиморасчетов
	|	И РасчетыПоСрокам.АналитикаУчетаПоПартнерам В (ВЫБРАТЬ КлючАналитики ИЗ АналитикаУчетаПоПартнерам)
	|	И &ОбъектРасчетов = РасчетыПоСрокам.ОбъектРасчетов
	|	И РасчетыПоСрокам.Активность
	|	И (РасчетыПоСрокам.КорОбъектРасчетов = Неопределено
	|		ИЛИ РасчетыПоСрокам.ДокументРегистратор ССЫЛКА Документ.ВзаимозачетЗадолженности)
	|СГРУППИРОВАТЬ ПО
	|	РасчетыПоСрокам.ДокументРегистратор";
	Запрос.Текст = ТекстЗапроса + ТекстЗапроса2;
	УстановитьПривилегированныйРежим(Истина);
	Запрос.Выполнить();
	УстановитьПривилегированныйРежим(Ложь);
	ТекстЗапроса = "
|ВЫБРАТЬ
|	РасчетыСКлиентами.АналитикаУчетаПоПартнерам          КАК АналитикаУчетаПоПартнерам,
|	РасчетыСКлиентами.АналитикаУчетаПоПартнерам.Партнер  КАК Партнер,
|	РасчетыСКлиентами.ОбъектРасчетов.Организация         КАК Организация,
|	РасчетыСКлиентами.ОбъектРасчетов.Контрагент          КАК Контрагент,
|	РасчетыСКлиентами.ОбъектРасчетов.Договор             КАК Договор,
|	РасчетыСКлиентами.ОбъектРасчетов.НаправлениеДеятельности КАК НаправлениеДеятельности,
|	РасчетыСКлиентами.ОбъектРасчетов                     КАК ОбъектРасчетов,
|	РасчетыСКлиентами.ОбъектРасчетов.Объект              КАК Объект,
|	РасчетыСКлиентами.Валюта                             КАК Валюта,
|	-РасчетыСКлиентами.ПредоплатаОстаток                 КАК СуммаАванса,
|	-РасчетыСКлиентами.ПредоплатаРеглОстаток             КАК СуммаРегл,
|	-РасчетыСКлиентами.ПредоплатаУпрОстаток              КАК СуммаУпр,
|	РасчетыСКлиентами.ОбъектРасчетов.Дата                КАК Дата
|
|ПОМЕСТИТЬ ТаблицаОстатковПоДокументам
|ИЗ
|	РегистрНакопления.РасчетыСКлиентамиПоСрокам.Остатки(,
|		АналитикаУчетаПоПартнерам В (
|			ВЫБРАТЬ
|				АналитикаПоПартнерам.КлючАналитики КАК КлючАналитики
|			ИЗ
|				АналитикаУчетаПоПартнерам КАК АналитикаПоПартнерам
|			ГДЕ
|				АналитикаПоПартнерам.Организация В (&Организация)
|			)
|		И ОбъектРасчетов <> &ОбъектРасчетов
|	) КАК РасчетыСКлиентами
|	
|ГДЕ
|	РасчетыСКлиентами.ПредоплатаОстаток > 0
|	И РасчетыСКлиентами.ОбъектРасчетов.Объект <> НЕОПРЕДЕЛЕНО
|ИНДЕКСИРОВАТЬ ПО
|	АналитикаУчетаПоПартнерам,
|	ОбъектРасчетов,
|	Валюта
|;";

ТекстЗапроса = ТекстЗапроса + "
	|////////////////////////////////////////////////////////////////////////////////
	|ВЫБРАТЬ
	|	ТаблицаОстатковПоДокументам.ОбъектРасчетов                      КАК ОбъектРасчетов,
	|	ТаблицаОстатковПоДокументам.Валюта                            КАК ВалютаВзаиморасчетов,
	|	ТаблицаОстатковПоДокументам.Организация                       КАК Организация,
	|	ТаблицаОстатковПоДокументам.Партнер                           КАК Партнер,
	|	ТаблицаОстатковПоДокументам.Контрагент                        КАК Контрагент,
	|	ТаблицаОстатковПоДокументам.Договор                           КАК Договор,
	|	СУММА(-ТаблицаОстатковПоДокументам.СуммаАванса)               КАК ДоступноКЗачету,
	|	СУММА(-ТаблицаОстатковПоДокументам.СуммаРегл)                 КАК СуммаРегл,
	|	СУММА(-ТаблицаОстатковПоДокументам.СуммаУпр)                  КАК СуммаУпр,
	|	ВЫБОР
	|		КОГДА ТаблицаОстатковПоДокументам.Договор = &Договор ТОГДА
	|			1
	|		ИНАЧЕ
	|			2
	|	КОНЕЦ                                                         КАК Порядок
	|ИЗ
	|	ТаблицаОстатковПоДокументам КАК ТаблицаОстатковПоДокументам
	|		ЛЕВОЕ СОЕДИНЕНИЕ ВтНераспределенныеПлатежи КАК НераспределенныеПлатежи
	|			ПО НераспределенныеПлатежи.ОбъектРасчетов = ТаблицаОстатковПоДокументам.ОбъектРасчетов
	|ГДЕ
	|	НераспределенныеПлатежи.ОбъектРасчетов ЕСТЬ NULL
	|
	|СГРУППИРОВАТЬ ПО
	|	ТаблицаОстатковПоДокументам.ОбъектРасчетов,
	|	ТаблицаОстатковПоДокументам.Валюта,
	|	ТаблицаОстатковПоДокументам.Организация,
	|	ТаблицаОстатковПоДокументам.Партнер,
	|	ТаблицаОстатковПоДокументам.Контрагент,
	|	ТаблицаОстатковПоДокументам.Договор,
	|	ТаблицаОстатковПоДокументам.Дата
	|
	|УПОРЯДОЧИТЬ ПО
	|	Организация,
	|	Порядок,
	|	ТаблицаОстатковПоДокументам.Дата
	|";
	Запрос.Текст = ТекстЗапроса;
	Результат = Запрос.Выполнить().Выбрать();
	Если Результат.Количество() = 0 Тогда
		Возврат;
	КонецЕсли;
	СуммаАванса = 0;
	ВзаимоЗачетЗадолженности = Документы.ВзаимозачетЗадолженности.СоздатьДокумент();
	ВзаимоЗачетЗадолженности.Валюта = РеквизитыЗаказа.Валюта;
	ВзаимоЗачетЗадолженности.ВидОперации = Перечисления.ВидыОперацийВзаимозачетаЗадолженности.ПереносАвансаКлиентаОрганизацияКонтрагент;
	ВзаимоЗачетЗадолженности.Дата = ТекущаяДатаСеанса();
	ВзаимоЗачетЗадолженности.ДокументОснование = Заказ;
	ВзаимоЗачетЗадолженности.Комментарий = "Перенос аванса клиента по запросу с заказа CRM - " + РеквизитыЗаказа.НомерПоДаннымКлиента;;
	ВзаимоЗачетЗадолженности.КонтрагентДебитор = РеквизитыЗаказа.Контрагент;
	ВзаимоЗачетЗадолженности.КонтрагентКредитор = РеквизитыЗаказа.Контрагент;
	ВзаимоЗачетЗадолженности.Организация = РеквизитыЗаказа.Организация;
	ВзаимоЗачетЗадолженности.ТипДебитора = Перечисления.ТипыУчастниковВзаимозачета.Клиент;
	ВзаимоЗачетЗадолженности.ТипКредитора= Перечисления.ТипыУчастниковВзаимозачета.Клиент;
	СтрокаДебиторскойЗадолженности = ВзаимоЗачетЗадолженности.ДебиторскаяЗадолженность.Добавить();
	СтрокаДебиторскойЗадолженности.ВалютаВзаиморасчетов = РеквизитыЗаказа.Валюта;
	СтрокаДебиторскойЗадолженности.ОбъектРасчетов = РеквизитыЗаказа.ОбъектРасчетов;
	СтрокаДебиторскойЗадолженности.Организация = ВзаимоЗачетЗадолженности.Организация;
	СтрокаДебиторскойЗадолженности.Партнер= РеквизитыЗаказа.Партнер;
	СтрокаДебиторскойЗадолженности.ТипРасчетов = Перечисления.ТипыРасчетовСПартнерами.РасчетыСКлиентом; 
	
	ИсключающиеВариантыОбеспеченияДляЗаказов = Новый Массив();
	ИсключающиеВариантыОбеспеченияДляЗаказов.Добавить(Перечисления.ВариантыОбеспечения.КОбеспечению);
	ИсключающиеВариантыОбеспеченияДляЗаказов.Добавить(Перечисления.ВариантыОбеспечения.СоСклада);
	Пока Результат.Следующий() Цикл
		
		ОснованиеАванса = ОбщегоНазначения.ЗначениеРеквизитаОбъекта(Результат.ОбъектРасчетов,"Объект" );
		Если ТипЗнч(ОснованиеАванса) = Тип("ДокументСсылка.ЗаказКлиента") Тогда
			СостояниеЗаказа = УТ11_ПолучитьСостояниеЗаказа(ОснованиеАванса);
			Если СостояниеЗаказа = Перечисления.СостоянияЗаказовКлиентов.ГотовКЗакрытию ИЛИ
			СостояниеЗаказа = Перечисления.СостоянияЗаказовКлиентов.Закрыт Тогда
				//======================================================================================================================
				//Cоздаем перенос аванса и суммируем переменную СуммаАванса
				СтрокаКредиторскойЗадолженности = ВзаимоЗачетЗадолженности.КредиторскаяЗадолженность.Добавить();
				ЗаполнитьЗначенияСвойств(СтрокаКредиторскойЗадолженности, СтрокаДебиторскойЗадолженности);
				СтрокаКредиторскойЗадолженности.ОбъектРасчетов = Результат.ОбъектРасчетов;
				СтрокаКредиторскойЗадолженности.Сумма = Результат.ДоступноКЗачету;
				СтрокаКредиторскойЗадолженности.СуммаВзаиморасчетов= Результат.ДоступноКЗачету;
				СтрокаКредиторскойЗадолженности.СуммаРегл = Результат.ДоступноКЗачету;
				СтрокаКредиторскойЗадолженности.СуммаУпр = Результат.ДоступноКЗачету;
				СуммаАванса = СуммаАванса + Результат.ДоступноКЗачету;
			ИначеЕсли СостояниеЗаказа = Перечисления.СостоянияЗаказовКлиентов.ОжидаетсяСогласование Тогда
				//======================================================================================================================
				//ищем есть ли товары к обеспечению или в резерве если есть то пропускаем
				// в цикле - sorry)
				Запрос = Новый Запрос;
				Запрос.Текст =
				"ВЫБРАТЬ
				|	ЗаказКлиентаТовары.НомерСтроки
				|ИЗ
				|	Документ.ЗаказКлиента.Товары КАК ЗаказКлиентаТовары
				|ГДЕ
				|	ЗаказКлиентаТовары.ВариантОбеспечения В (&ВариантОбеспечения)
				|	И ЗаказКлиентаТовары.Ссылка = &Ссылка";
				Запрос.УстановитьПараметр("ВариантОбеспечения", ИсключающиеВариантыОбеспеченияДляЗаказов);
				Запрос.УстановитьПараметр("Ссылка", ОснованиеАванса);
				РезультатЗапроса = Запрос.Выполнить();
				Если НЕ РезультатЗапроса.Пустой() Тогда
					Продолжить;
				КонецЕсли;
				//======================================================================================================================
				//создаем перенос аванса и суммируем переменную СуммаАванса
				СтрокаКредиторскойЗадолженности = ВзаимоЗачетЗадолженности.КредиторскаяЗадолженность.Добавить();
				ЗаполнитьЗначенияСвойств(СтрокаКредиторскойЗадолженности, СтрокаДебиторскойЗадолженности);
				СтрокаКредиторскойЗадолженности.ОбъектРасчетов = Результат.ОбъектРасчетов;
				СтрокаКредиторскойЗадолженности.Сумма = Результат.ДоступноКЗачету;
				СтрокаКредиторскойЗадолженности.СуммаВзаиморасчетов= Результат.ДоступноКЗачету;
				СтрокаКредиторскойЗадолженности.СуммаРегл = Результат.ДоступноКЗачету;
				СтрокаКредиторскойЗадолженности.СуммаУпр = Результат.ДоступноКЗачету;
				СуммаАванса = СуммаАванса + Результат.ДоступноКЗачету;
			Иначе
				Продолжить;
			КонецЕсли;
		Иначе
			//======================================================================================================================
			//создаем перенос аванса и суммируем переменную СуммаАванса
			СтрокаКредиторскойЗадолженности = ВзаимоЗачетЗадолженности.КредиторскаяЗадолженность.Добавить();
				ЗаполнитьЗначенияСвойств(СтрокаКредиторскойЗадолженности, СтрокаДебиторскойЗадолженности);
				СтрокаКредиторскойЗадолженности.ОбъектРасчетов = Результат.ОбъектРасчетов;
				СтрокаКредиторскойЗадолженности.Сумма = Результат.ДоступноКЗачету;
				СтрокаКредиторскойЗадолженности.СуммаВзаиморасчетов= Результат.ДоступноКЗачету;
				СтрокаКредиторскойЗадолженности.СуммаРегл = Результат.ДоступноКЗачету;
				СтрокаКредиторскойЗадолженности.СуммаУпр = Результат.ДоступноКЗачету;
				СуммаАванса = СуммаАванса + Результат.ДоступноКЗачету;
		КонецЕсли;
	КонецЦикла;
	Если СуммаАванса = 0 Тогда
		Возврат;
	КонецЕсли;
	ВзаимоЗачетЗадолженности.СуммаДокумента = СуммаАванса;
	ВзаимоЗачетЗадолженности.СуммаРегл = СуммаАванса;
	ВзаимоЗачетЗадолженности.СуммаУпр = СуммаАванса;
	СтрокаДебиторскойЗадолженности.СуммаВзаиморасчетов = СуммаАванса;
	СтрокаДебиторскойЗадолженности.СуммаРегл = СуммаАванса;
	СтрокаДебиторскойЗадолженности.СуммаУпр = СуммаАванса;
	Попытка
		ВзаимоЗачетЗадолженности.Записать(РежимЗаписиДокумента.Проведение);
		Возврат;
	Исключение
		ВзаимоЗачетЗадолженности.Записать(РежимЗаписиДокумента.Запись);
		Возврат;
	КонецПопытки;
КонецПроцедуры

#КонецОбласти
