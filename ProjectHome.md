Открытая реализация концепции Telecommunication Management Network  (TMN )
Система реализована на Perl  и БД MYSQL
Для управления разными типами оборудования написаны несколько библиотек и каждый желающий может дописать свою низкоуровневую библиотеку для своего оборудования, если его ещё нет.  Нужно лишь описать несколько атомарных действий над оборудованием по типу транзакций. В текущих библиотеках описано лишь несколько нужных мне действий с оборудованием, но полагаю что их перечень придётся пересмотреть или расширить.

Система прежде всего рассчитана на администраторов сетей и службы техподдержки ISP. И по этой причине предполагает гибкость в доработке или переделке алгоритмов работы, ведь универсальное решение для всего многообразия систем создать практически нереально. Именно по этой причине я пишу её на Perl.

Система тесно связана с другими Open Source продуктами - MYSQL , FreeRADIUS , Nagios , Apache  и другими. Кроме того она очень тесно взаимодействует с билинговой системой провайдера.

--- Google translation RU -> EN ----

Open source implementation of the concept of Telecommunication Management Network (TMN)
The system is implemented in Perl and MYSQL Database
To manage different types of equipment written several libraries and everyone can finish their low-level library for your equipment, if it's not. Need only describe a few atomic actions on the equipment by type of transactions. In the current library is described only a few I need the action with the equipment, but I believe that their list will be revised or expanded.
I am open for discussions and suggestions.

The system primarily designed for network administrators and help desk ISP. And for this reason requires flexibility in the revision or alteration of algorithms, as a universal solution for all variety of systems to create almost unreal. It is for this reason that I write it in Perl.

The system is closely linked with other Open Source products - MYSQL, FreeRADIUS, Nagios, Apache and others. In addition it is very closely with the billing system provider.