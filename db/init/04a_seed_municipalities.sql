PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA busy_timeout = 5000;

/* 04a_seed_municipalities.sql - SQLite version
   Base: INE, Valores de las variables de departamento y municipio (2016).
   Complementos recientes: Sipacate (Escuintla) y Petatan (Huehuetenango).
*/
BEGIN TRANSACTION;

UPDATE municipalities
SET name = 'San Rafael Pié de la Cuesta'
WHERE name = 'San Rafael Pie de la Cuesta'
  AND department_id = (SELECT id FROM departments WHERE name = 'San Marcos');

INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Guatemala' FROM departments WHERE name = 'Guatemala';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santa Catarina Pinula' FROM departments WHERE name = 'Guatemala';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San José Pinula' FROM departments WHERE name = 'Guatemala';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San José del Golfo' FROM departments WHERE name = 'Guatemala';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Palencia' FROM departments WHERE name = 'Guatemala';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Chinautla' FROM departments WHERE name = 'Guatemala';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Pedro Ayampuc' FROM departments WHERE name = 'Guatemala';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Mixco' FROM departments WHERE name = 'Guatemala';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Pedro Sacatepéquez' FROM departments WHERE name = 'Guatemala';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Juan Sacatepéquez' FROM departments WHERE name = 'Guatemala';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Raymundo' FROM departments WHERE name = 'Guatemala';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Chuarrancho' FROM departments WHERE name = 'Guatemala';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Fraijanes' FROM departments WHERE name = 'Guatemala';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Amatitlán' FROM departments WHERE name = 'Guatemala';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Villa Nueva' FROM departments WHERE name = 'Guatemala';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Villa Canales' FROM departments WHERE name = 'Guatemala';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Petapa' FROM departments WHERE name = 'Guatemala';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Guastatoya' FROM departments WHERE name = 'El Progreso';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Morazán' FROM departments WHERE name = 'El Progreso';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Agustín Acasaguastlán' FROM departments WHERE name = 'El Progreso';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Cristóbal Acasaguastlán' FROM departments WHERE name = 'El Progreso';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'El Jícaro' FROM departments WHERE name = 'El Progreso';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Sansare' FROM departments WHERE name = 'El Progreso';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Sanarate' FROM departments WHERE name = 'El Progreso';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Antonio la Paz' FROM departments WHERE name = 'El Progreso';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Antigua Guatemala' FROM departments WHERE name = 'Sacatepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Jocotenango' FROM departments WHERE name = 'Sacatepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Pastores' FROM departments WHERE name = 'Sacatepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Sumpango' FROM departments WHERE name = 'Sacatepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santo Domingo Xenacoj' FROM departments WHERE name = 'Sacatepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santiago Sacatepéquez' FROM departments WHERE name = 'Sacatepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Bartolomé Milpas Altas' FROM departments WHERE name = 'Sacatepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Lucas Sacatepéquez' FROM departments WHERE name = 'Sacatepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santa Lucía Milpas Altas' FROM departments WHERE name = 'Sacatepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Magdalena Milpas Altas' FROM departments WHERE name = 'Sacatepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santa María de Jesús' FROM departments WHERE name = 'Sacatepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Ciudad Vieja' FROM departments WHERE name = 'Sacatepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Miguel Dueñas' FROM departments WHERE name = 'Sacatepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Alotenango' FROM departments WHERE name = 'Sacatepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Antonio Aguas Calientes' FROM departments WHERE name = 'Sacatepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santa Catarina Barahona' FROM departments WHERE name = 'Sacatepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Chimaltenango' FROM departments WHERE name = 'Chimaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San José Poaquil' FROM departments WHERE name = 'Chimaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Martín Jilotepeque' FROM departments WHERE name = 'Chimaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Comalapa' FROM departments WHERE name = 'Chimaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santa Apolonia' FROM departments WHERE name = 'Chimaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Tecpán Guatemala' FROM departments WHERE name = 'Chimaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Patzún' FROM departments WHERE name = 'Chimaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Pochuta' FROM departments WHERE name = 'Chimaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Patzicía' FROM departments WHERE name = 'Chimaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santa Cruz Balanyá' FROM departments WHERE name = 'Chimaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Acatenango' FROM departments WHERE name = 'Chimaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Yepocapa' FROM departments WHERE name = 'Chimaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Andrés Itzapa' FROM departments WHERE name = 'Chimaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Parramos' FROM departments WHERE name = 'Chimaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Zaragoza' FROM departments WHERE name = 'Chimaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'El Tejar' FROM departments WHERE name = 'Chimaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Escuintla' FROM departments WHERE name = 'Escuintla';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santa Lucía Cotzumalguapa' FROM departments WHERE name = 'Escuintla';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'La Democracia' FROM departments WHERE name = 'Escuintla';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Siquinalá' FROM departments WHERE name = 'Escuintla';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Masagua' FROM departments WHERE name = 'Escuintla';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Tiquisate' FROM departments WHERE name = 'Escuintla';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'La Gomera' FROM departments WHERE name = 'Escuintla';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Guanagazapa' FROM departments WHERE name = 'Escuintla';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San José' FROM departments WHERE name = 'Escuintla';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Iztapa' FROM departments WHERE name = 'Escuintla';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Palín' FROM departments WHERE name = 'Escuintla';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Vicente Pacaya' FROM departments WHERE name = 'Escuintla';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Nueva Concepción' FROM departments WHERE name = 'Escuintla';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Sipacate' FROM departments WHERE name = 'Escuintla';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Cuilapa' FROM departments WHERE name = 'Santa Rosa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Barberena' FROM departments WHERE name = 'Santa Rosa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santa Rosa de Lima' FROM departments WHERE name = 'Santa Rosa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Casillas' FROM departments WHERE name = 'Santa Rosa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Rafael las Flores' FROM departments WHERE name = 'Santa Rosa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Oratorio' FROM departments WHERE name = 'Santa Rosa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Juan Tecuaco' FROM departments WHERE name = 'Santa Rosa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Chiquimulilla' FROM departments WHERE name = 'Santa Rosa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Taxisco' FROM departments WHERE name = 'Santa Rosa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santa María Ixhuatán' FROM departments WHERE name = 'Santa Rosa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Guazacapán' FROM departments WHERE name = 'Santa Rosa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santa Cruz Naranjo' FROM departments WHERE name = 'Santa Rosa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Pueblo Nuevo Viñas' FROM departments WHERE name = 'Santa Rosa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Nueva Santa Rosa' FROM departments WHERE name = 'Santa Rosa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Sololá' FROM departments WHERE name = 'Sololá';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San José Chacayá' FROM departments WHERE name = 'Sololá';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santa María Visitación' FROM departments WHERE name = 'Sololá';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santa Lucía Utatlán' FROM departments WHERE name = 'Sololá';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Nahualá' FROM departments WHERE name = 'Sololá';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santa Catarina Ixtahuacán' FROM departments WHERE name = 'Sololá';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santa Clara la Laguna' FROM departments WHERE name = 'Sololá';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Concepción' FROM departments WHERE name = 'Sololá';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Andrés Semetabaj' FROM departments WHERE name = 'Sololá';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Panajachel' FROM departments WHERE name = 'Sololá';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santa Catarina Palopó' FROM departments WHERE name = 'Sololá';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Antonio Palopó' FROM departments WHERE name = 'Sololá';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Lucas Tolimán' FROM departments WHERE name = 'Sololá';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santa Cruz la Laguna' FROM departments WHERE name = 'Sololá';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Pablo la Laguna' FROM departments WHERE name = 'Sololá';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Marcos la Laguna' FROM departments WHERE name = 'Sololá';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Juan la Laguna' FROM departments WHERE name = 'Sololá';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Pedro la Laguna' FROM departments WHERE name = 'Sololá';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santiago Atitlán' FROM departments WHERE name = 'Sololá';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Totonicapán' FROM departments WHERE name = 'Totonicapán';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Cristóbal Totonicapán' FROM departments WHERE name = 'Totonicapán';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Francisco el Alto' FROM departments WHERE name = 'Totonicapán';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Andrés Xecul' FROM departments WHERE name = 'Totonicapán';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Momostenango' FROM departments WHERE name = 'Totonicapán';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santa María Chiquimula' FROM departments WHERE name = 'Totonicapán';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santa Lucía la Reforma' FROM departments WHERE name = 'Totonicapán';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Bartolo' FROM departments WHERE name = 'Totonicapán';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Quetzaltenango' FROM departments WHERE name = 'Quetzaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Salcajá' FROM departments WHERE name = 'Quetzaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Olintepeque' FROM departments WHERE name = 'Quetzaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Carlos Sija' FROM departments WHERE name = 'Quetzaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Sibilia' FROM departments WHERE name = 'Quetzaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Cabricán' FROM departments WHERE name = 'Quetzaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Cajolá' FROM departments WHERE name = 'Quetzaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Miguel Siguilá' FROM departments WHERE name = 'Quetzaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Ostuncalco' FROM departments WHERE name = 'Quetzaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Mateo' FROM departments WHERE name = 'Quetzaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Concepción Chiquirichapa' FROM departments WHERE name = 'Quetzaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Martín Sacatepéquez' FROM departments WHERE name = 'Quetzaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Almolonga' FROM departments WHERE name = 'Quetzaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Cantel' FROM departments WHERE name = 'Quetzaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Huitán' FROM departments WHERE name = 'Quetzaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Zunil' FROM departments WHERE name = 'Quetzaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Colomba' FROM departments WHERE name = 'Quetzaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Francisco la Unión' FROM departments WHERE name = 'Quetzaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'El Palmar' FROM departments WHERE name = 'Quetzaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Coatepeque' FROM departments WHERE name = 'Quetzaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Génova' FROM departments WHERE name = 'Quetzaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Flores Costa Cuca' FROM departments WHERE name = 'Quetzaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'La Esperanza' FROM departments WHERE name = 'Quetzaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Palestina de los Altos' FROM departments WHERE name = 'Quetzaltenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Mazatenango' FROM departments WHERE name = 'Suchitepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Cuyotenango' FROM departments WHERE name = 'Suchitepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Francisco Zapotitlán' FROM departments WHERE name = 'Suchitepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Bernardino' FROM departments WHERE name = 'Suchitepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San José el Idolo' FROM departments WHERE name = 'Suchitepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santo Domingo Suchitepéquez' FROM departments WHERE name = 'Suchitepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Lorenzo' FROM departments WHERE name = 'Suchitepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Samayac' FROM departments WHERE name = 'Suchitepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Pablo Jocopilas' FROM departments WHERE name = 'Suchitepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Antonio Suchitepéquez' FROM departments WHERE name = 'Suchitepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Miguel Panán' FROM departments WHERE name = 'Suchitepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Gabriel' FROM departments WHERE name = 'Suchitepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Chicacao' FROM departments WHERE name = 'Suchitepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Patulul' FROM departments WHERE name = 'Suchitepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santa Bárbara' FROM departments WHERE name = 'Suchitepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Juan Bautista' FROM departments WHERE name = 'Suchitepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santo Tomás la Unión' FROM departments WHERE name = 'Suchitepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Zunilito' FROM departments WHERE name = 'Suchitepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Pueblo Nuevo' FROM departments WHERE name = 'Suchitepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Río Bravo' FROM departments WHERE name = 'Suchitepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San José La Máquina' FROM departments WHERE name = 'Suchitepéquez';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Retalhuleu' FROM departments WHERE name = 'Retalhuleu';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Sebastián' FROM departments WHERE name = 'Retalhuleu';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santa Cruz Muluá' FROM departments WHERE name = 'Retalhuleu';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Martín Zapotitlán' FROM departments WHERE name = 'Retalhuleu';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Felipe' FROM departments WHERE name = 'Retalhuleu';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Andrés Villa Seca' FROM departments WHERE name = 'Retalhuleu';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Champerico' FROM departments WHERE name = 'Retalhuleu';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Nuevo San Carlos' FROM departments WHERE name = 'Retalhuleu';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'El Asintal' FROM departments WHERE name = 'Retalhuleu';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Marcos' FROM departments WHERE name = 'San Marcos';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Pedro Sacatepéquez' FROM departments WHERE name = 'San Marcos';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Antonio Sacatepéquez' FROM departments WHERE name = 'San Marcos';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Comitancillo' FROM departments WHERE name = 'San Marcos';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Miguel Ixtahuacán' FROM departments WHERE name = 'San Marcos';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Concepción Tutuapa' FROM departments WHERE name = 'San Marcos';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Tacaná' FROM departments WHERE name = 'San Marcos';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Sibinal' FROM departments WHERE name = 'San Marcos';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Tajumulco' FROM departments WHERE name = 'San Marcos';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Tejutla' FROM departments WHERE name = 'San Marcos';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Rafael Pié de la Cuesta' FROM departments WHERE name = 'San Marcos';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Nuevo Progreso' FROM departments WHERE name = 'San Marcos';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'El Tumbador' FROM departments WHERE name = 'San Marcos';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'El Rodeo' FROM departments WHERE name = 'San Marcos';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Malacatán' FROM departments WHERE name = 'San Marcos';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Catarina' FROM departments WHERE name = 'San Marcos';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Ayutla' FROM departments WHERE name = 'San Marcos';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Ocós' FROM departments WHERE name = 'San Marcos';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Pablo' FROM departments WHERE name = 'San Marcos';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'El Quetzal' FROM departments WHERE name = 'San Marcos';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'La Reforma' FROM departments WHERE name = 'San Marcos';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Pajapita' FROM departments WHERE name = 'San Marcos';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Ixchiguán' FROM departments WHERE name = 'San Marcos';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San José Ojetenán' FROM departments WHERE name = 'San Marcos';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Cristóbal Cucho' FROM departments WHERE name = 'San Marcos';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Sipacapa' FROM departments WHERE name = 'San Marcos';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Esquipulas Palo Gordo' FROM departments WHERE name = 'San Marcos';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Río Blanco' FROM departments WHERE name = 'San Marcos';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Lorenzo' FROM departments WHERE name = 'San Marcos';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'La Blanca' FROM departments WHERE name = 'San Marcos';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Huehuetenango' FROM departments WHERE name = 'Huehuetenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Chiantla' FROM departments WHERE name = 'Huehuetenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Malacatancito' FROM departments WHERE name = 'Huehuetenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Cuilco' FROM departments WHERE name = 'Huehuetenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Nentón' FROM departments WHERE name = 'Huehuetenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Pedro Necta' FROM departments WHERE name = 'Huehuetenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Jacaltenango' FROM departments WHERE name = 'Huehuetenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Soloma' FROM departments WHERE name = 'Huehuetenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Ixtahuacán' FROM departments WHERE name = 'Huehuetenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santa Bárbara' FROM departments WHERE name = 'Huehuetenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'La Libertad' FROM departments WHERE name = 'Huehuetenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'La Democracia' FROM departments WHERE name = 'Huehuetenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Miguel Acatán' FROM departments WHERE name = 'Huehuetenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Rafael la Independencia' FROM departments WHERE name = 'Huehuetenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Todos Santos Cuchumatán' FROM departments WHERE name = 'Huehuetenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Juan Atitán' FROM departments WHERE name = 'Huehuetenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santa Eulalia' FROM departments WHERE name = 'Huehuetenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Mateo Ixtatán' FROM departments WHERE name = 'Huehuetenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Colotenango' FROM departments WHERE name = 'Huehuetenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Sebastián Huehuetenango' FROM departments WHERE name = 'Huehuetenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Tectitán' FROM departments WHERE name = 'Huehuetenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Concepción Huista' FROM departments WHERE name = 'Huehuetenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Juan Ixcoy' FROM departments WHERE name = 'Huehuetenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Antonio Huista' FROM departments WHERE name = 'Huehuetenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Sebastián Coatán' FROM departments WHERE name = 'Huehuetenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Barillas' FROM departments WHERE name = 'Huehuetenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Aguacatán' FROM departments WHERE name = 'Huehuetenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Rafael Petzal' FROM departments WHERE name = 'Huehuetenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Gaspar Ixchil' FROM departments WHERE name = 'Huehuetenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santiago Chimaltenango' FROM departments WHERE name = 'Huehuetenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santa Ana Huista' FROM departments WHERE name = 'Huehuetenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Unión Cantinil' FROM departments WHERE name = 'Huehuetenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Petatán' FROM departments WHERE name = 'Huehuetenango';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santa Cruz del Quiché' FROM departments WHERE name = 'Quiché';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Chiché' FROM departments WHERE name = 'Quiché';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Chinique' FROM departments WHERE name = 'Quiché';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Zacualpa' FROM departments WHERE name = 'Quiché';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Chajul' FROM departments WHERE name = 'Quiché';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Chichicastenango' FROM departments WHERE name = 'Quiché';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Patzité' FROM departments WHERE name = 'Quiché';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Antonio Ilotenango' FROM departments WHERE name = 'Quiché';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Pedro Jocopilas' FROM departments WHERE name = 'Quiché';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Cunén' FROM departments WHERE name = 'Quiché';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Juan Cotzal' FROM departments WHERE name = 'Quiché';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Joyabaj' FROM departments WHERE name = 'Quiché';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Nebaj' FROM departments WHERE name = 'Quiché';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Andrés Sajcabajá' FROM departments WHERE name = 'Quiché';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Uspantán' FROM departments WHERE name = 'Quiché';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Sacapulas' FROM departments WHERE name = 'Quiché';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Bartolomé Jocotenango' FROM departments WHERE name = 'Quiché';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Canillá' FROM departments WHERE name = 'Quiché';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Chicamán' FROM departments WHERE name = 'Quiché';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Ixcán' FROM departments WHERE name = 'Quiché';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Pachalum' FROM departments WHERE name = 'Quiché';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Salamá' FROM departments WHERE name = 'Baja Verapaz';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Miguel Chicaj' FROM departments WHERE name = 'Baja Verapaz';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Rabinal' FROM departments WHERE name = 'Baja Verapaz';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Cubulco' FROM departments WHERE name = 'Baja Verapaz';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Granados' FROM departments WHERE name = 'Baja Verapaz';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'El Chol' FROM departments WHERE name = 'Baja Verapaz';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Jerónimo' FROM departments WHERE name = 'Baja Verapaz';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Purulhá' FROM departments WHERE name = 'Baja Verapaz';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Cobán' FROM departments WHERE name = 'Alta Verapaz';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santa Cruz Verapaz' FROM departments WHERE name = 'Alta Verapaz';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Cristóbal Verapaz' FROM departments WHERE name = 'Alta Verapaz';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Tactic' FROM departments WHERE name = 'Alta Verapaz';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Tamahú' FROM departments WHERE name = 'Alta Verapaz';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Tucurú' FROM departments WHERE name = 'Alta Verapaz';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Panzós' FROM departments WHERE name = 'Alta Verapaz';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Senahú' FROM departments WHERE name = 'Alta Verapaz';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Pedro Carchá' FROM departments WHERE name = 'Alta Verapaz';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Juan Chamelco' FROM departments WHERE name = 'Alta Verapaz';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Lanquín' FROM departments WHERE name = 'Alta Verapaz';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Cahabón' FROM departments WHERE name = 'Alta Verapaz';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Chisec' FROM departments WHERE name = 'Alta Verapaz';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Chahal' FROM departments WHERE name = 'Alta Verapaz';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Fray Bartolomé de las Casas' FROM departments WHERE name = 'Alta Verapaz';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santa Catalina la Tinta' FROM departments WHERE name = 'Alta Verapaz';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Raxruhá' FROM departments WHERE name = 'Alta Verapaz';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Flores' FROM departments WHERE name = 'Petén';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San José' FROM departments WHERE name = 'Petén';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Benito' FROM departments WHERE name = 'Petén';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Andrés' FROM departments WHERE name = 'Petén';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'La Libertad' FROM departments WHERE name = 'Petén';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Francisco' FROM departments WHERE name = 'Petén';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santa Ana' FROM departments WHERE name = 'Petén';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Dolores' FROM departments WHERE name = 'Petén';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Luis' FROM departments WHERE name = 'Petén';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Sayaxché' FROM departments WHERE name = 'Petén';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Melchor de Mencos' FROM departments WHERE name = 'Petén';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Poptún' FROM departments WHERE name = 'Petén';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Las Cruces' FROM departments WHERE name = 'Petén';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'El Chal' FROM departments WHERE name = 'Petén';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Puerto Barrios' FROM departments WHERE name = 'Izabal';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Livingston' FROM departments WHERE name = 'Izabal';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'El Estor' FROM departments WHERE name = 'Izabal';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Morales' FROM departments WHERE name = 'Izabal';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Los Amates' FROM departments WHERE name = 'Izabal';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Zacapa' FROM departments WHERE name = 'Zacapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Estanzuela' FROM departments WHERE name = 'Zacapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Río Hondo' FROM departments WHERE name = 'Zacapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Gualán' FROM departments WHERE name = 'Zacapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Teculután' FROM departments WHERE name = 'Zacapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Usumatlán' FROM departments WHERE name = 'Zacapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Cabañas' FROM departments WHERE name = 'Zacapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Diego' FROM departments WHERE name = 'Zacapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'La Unión' FROM departments WHERE name = 'Zacapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Huité' FROM departments WHERE name = 'Zacapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Jorge' FROM departments WHERE name = 'Zacapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Chiquimula' FROM departments WHERE name = 'Chiquimula';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San José La Arada' FROM departments WHERE name = 'Chiquimula';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Juan Ermita' FROM departments WHERE name = 'Chiquimula';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Jocotán' FROM departments WHERE name = 'Chiquimula';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Camotán' FROM departments WHERE name = 'Chiquimula';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Olopa' FROM departments WHERE name = 'Chiquimula';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Esquipulas' FROM departments WHERE name = 'Chiquimula';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Concepción Las Minas' FROM departments WHERE name = 'Chiquimula';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Quetzaltepeque' FROM departments WHERE name = 'Chiquimula';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Jacinto' FROM departments WHERE name = 'Chiquimula';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Ipala' FROM departments WHERE name = 'Chiquimula';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Jalapa' FROM departments WHERE name = 'Jalapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Pedro Pinula' FROM departments WHERE name = 'Jalapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Luis Jilotepeque' FROM departments WHERE name = 'Jalapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Manuel Chaparrón' FROM departments WHERE name = 'Jalapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San Carlos Alzatate' FROM departments WHERE name = 'Jalapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Monjas' FROM departments WHERE name = 'Jalapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Mataquescuintla' FROM departments WHERE name = 'Jalapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Jutiapa' FROM departments WHERE name = 'Jutiapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'El Progreso' FROM departments WHERE name = 'Jutiapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Santa Catarina Mita' FROM departments WHERE name = 'Jutiapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Agua Blanca' FROM departments WHERE name = 'Jutiapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Asunción Mita' FROM departments WHERE name = 'Jutiapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Yupiltepeque' FROM departments WHERE name = 'Jutiapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Atescatempa' FROM departments WHERE name = 'Jutiapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Jerez' FROM departments WHERE name = 'Jutiapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'El Adelanto' FROM departments WHERE name = 'Jutiapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Zapotitlán' FROM departments WHERE name = 'Jutiapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Comapa' FROM departments WHERE name = 'Jutiapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Jalpatagua' FROM departments WHERE name = 'Jutiapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Conguaco' FROM departments WHERE name = 'Jutiapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Moyuta' FROM departments WHERE name = 'Jutiapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Pasaco' FROM departments WHERE name = 'Jutiapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'San José Acatempa' FROM departments WHERE name = 'Jutiapa';
INSERT OR IGNORE INTO municipalities (department_id, name)
SELECT id, 'Quesada' FROM departments WHERE name = 'Jutiapa';

DELETE FROM municipalities
WHERE department_id = (SELECT id FROM departments WHERE name = 'San Marcos')
  AND name IN ('San Rafael Pie de la Cuesta', 'San Rafael Pi? de la Cuesta')
  AND EXISTS (
    SELECT 1
    FROM municipalities keep
    WHERE keep.department_id = municipalities.department_id
      AND keep.name = 'San Rafael Pié de la Cuesta'
  );

DELETE FROM municipalities
WHERE department_id = (SELECT id FROM departments WHERE name = 'Huehuetenango')
  AND name = 'Petat?n'
  AND EXISTS (
    SELECT 1
    FROM municipalities keep
    WHERE keep.department_id = municipalities.department_id
      AND keep.name = 'Petatán'
  );

COMMIT;
