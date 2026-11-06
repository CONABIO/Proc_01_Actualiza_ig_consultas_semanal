DELIMITER $$

DROP PROCEDURE IF EXISTS `snib_privadas`.`01_Actualiza_ig_consultas` $$
CREATE DEFINER=`si`@`172.16.3.78` PROCEDURE `01_Actualiza_ig_consultas`()
BEGIN
  DECLARE msg TEXT;

	DECLARE EXIT HANDLER FOR SQLEXCEPTION
 	BEGIN

	 	GET DIAGNOSTICS CONDITION 1
        
	 	msg = MESSAGE_TEXT;
	
	 	INSERT INTO dwh.ValidaProcesosAutomaticos(Nombre_SP, TipoError, Mensaje)
	    								  VALUES ('snib_privadas.01_Actualiza_ig_consultas', 
	    								 		  'Error', 
	    								 		  msg);
	 
       SELECT msg AS Error;
        
	END; 

-- Eliminamos los registros que ya no estan vivos.
drop table if exists snib_privadas.regeliminados;

create table snib_privadas.regeliminados
select llaveejemplar as idejemplar
from snib.ejemplar_curatorial where estadoregistro<>'';

alter table snib_privadas.regeliminados add primary key(idejemplar);

delete i.* from snib_privadas.regeliminados r inner join snib_privadas.informaciongeoportal_consultas i using(idejemplar);

drop table if exists snib_privadas.regeliminados;

-- Se quito la creación de la tabla y se programo un respaldo de la tabla, porque el generar la copia de la tabla era muy tardado. (2024-08-29)

/*
drop table if exists snib_privadas.informaciongeoportal_consultas_respaldo;
 create table snib_privadas.informaciongeoportal_consultas_respaldo
select idejemplar,tiporestriccion,categoriaresidenciaaves,prioritaria,nivelprioridad,exoticainvasora,endemismo,iucn,nom059,cites,reftaxvalido_extenso,now() as fecharespaldo
from snib_privadas.informaciongeoportal_consultas; */

/* Agregado el 2026-09-22 para solo ingresar registros de nombre con cambio */

drop table if exists snib_privadas.nombreconcambios;

create table snib_privadas.nombreconcambios
select distinct IdNombre,IdNombreRel,IdCAT,TaxonConSubgenero,UltimaCategoriaTaxonomica,EstatusTaxon,AutorTaxon,
Genero,Subgenero,Especie_epiteto,CategInfra,NombreInfra,gruposcat
from dwh.H_CatalogoTaxonomico where fecha_insercion > DATE_FORMAT(DATE_SUB(NOW(), INTERVAL 7 DAY), '%Y-%m-%d');

alter table snib_privadas.nombreconcambios add index uno(IdCAT);

drop table if exists snib_privadas.Especie;

CREATE TABLE snib_privadas.Especie
SELECT distinct gruposcat,Genero,Subgenero,Especie_Epiteto
FROM snib_privadas.nombreconcambios
WHERE NombreInfra = "" and Especie_epiteto <> "";

ALTER TABLE snib_privadas.Especie ADD INDEX uno(Genero,Subgenero,Especie_epiteto,gruposcat);

drop table if exists snib_privadas.llavenombre_cambio;

create table snib_privadas.llavenombre_cambio
select distinct llavenombre
from snib_privadas.nombreconcambios nc inner join snib.nombre n on nc.idcat=n.idnombrecat
union
select llavenombre
from snib_privadas.nombreconcambios nc inner join snib.nombre n on nc.idcat=n.idnombrecatvalido
union
select n.llavenombre
from snib_privadas.Especie e inner join snib.nombre n on e.Genero = n.generocatvalido and e.Subgenero = n.subgenerocatvalido
and e.Especie_epiteto = n.epitetoespecificocatvalido and e.gruposcat = n.gruposcat
where n.epitetoinfraespecificocatvalido <> "" and n.categoriainfraespeciecatvalido in('subespecie','variedad','forma');

ALTER TABLE snib_privadas.llavenombre_cambio ADD PRIMARY KEY(llavenombre);


-- Es necesario hacer el distinct porque en la tabla informaciongeoportal_consultas se repiten llaveejemplar de las coordenadas privadas.
drop table if exists snib_privadas.ejemplar_nombre;
create table snib_privadas.ejemplar_nombre
select distinct llaveejemplar as idejemplar,e.llavenombre
from snib_privadas.llavenombre_cambio i inner join  snib.ejemplar_curatorial e using(llavenombre)
where estadoregistro='';


alter table snib_privadas.ejemplar_nombre add primary key(idejemplar),add index uno(llavenombre); 

call geoportal_trabajo.01_preparanombrecomun();
drop table if exists snib_privadas.nombrecomun;
CREATE TABLE snib_privadas.nombrecomun  (
  `llavenombre` VARCHAR(32) NOT NULL,
  `nombrecomun` TEXT NOT NULL,
  `nombrecomun_es` TEXT NOT NULL,
   PRIMARY KEY(`llavenombre`)
) ENGINE = Aria
CHARACTER SET utf8 COLLATE utf8_general_ci;

-- En la tabla antes creada agregamos la lista de nombres de la tabla nombre
INSERT INTO snib_privadas.nombrecomun(llavenombre,nombrecomun,nombrecomun_es)
select distinct llavenombre,'','' from snib_privadas.ejemplar_nombre;

-- Se llena el campo nombrecomunCatalogo obteniendo el valor de una tabla creada en el procedimiento 01_preparanombrecomun()
UPDATE snib_privadas.nombrecomun nc inner join geoportal_trabajo.nombrecomunCatalogoEspañol ncce on nc.llavenombre=ncce.llavenombre
SET nc.nombrecomun=ncce.nombrecomun;

-- Con la siguiente linea quitamos la parte de Lengua que viene entre parentesis
UPDATE snib_privadas.nombrecomun
set nombrecomun_es=snib_privadas.limpiaNombreComun(nombrecomun)
where nombrecomun<>'' and nombrecomun like "%(%";

UPDATE snib_privadas.nombrecomun
set nombrecomun_es=nombrecomun
where nombrecomun not like "%(%" and nombrecomun<>'';

DROP TABLE IF EXISTS snib_privadas.nombre;

create table snib_privadas.nombre
select llavenombre,grupo,subgrupo,reinocat,divisionphylumcat,clasecat,autoranioordencat,ordencat,subordencat,autoraniofamiliacat,familiacat,estatusfamiliacat,subfamiliacat,estatussubfamiliacat,tribucat,estatustribucat,
generocat,estatusgenerocat,autoraniogenerocat,subgenerocat,autoraniosubgenerocat,estatussubgenerocat,epitetoespecificocat,estatusespeciecat,autoranioespeciecat,categoriainfraespeciecat,epitetoinfraespecificocat,
estatusinfraespeciecat,autoranioinfraespeciecat,categoriainfraespecie2cat,epitetoinfraespecifico2cat,catdiccinfraespecie2cat,estatusinfraespecie2cat,autoranioinfraespecie2cat,idnombrecat,cattaxcat,catalogocat,
comentarioscat,fuentecat,reinooriginal,divisionphylumoriginal,claseoriginal,ordenoriginal,autoranioordenoriginal,subordenoriginal,familiaoriginal,autoraniofamiliaoriginal,subfamiliaoriginal,tribuoriginal,generooriginal,
autoraniogenerooriginal,estatusgenerooriginal,subgenerooriginal,epitetoespecificooriginal,autoranioespecieoriginal,estatusespecieoriginal,categoriainfraespecieoriginal,epitetoinfraespecificooriginal,
autoranioinfraespecieoriginal,estatusinfraespecieoriginal,categoriainfraespecieoriginal2,epitetoinfraespecificooriginal2,autoranioinfraespecieoriginal2,estatusinfraespecieoriginal2,idnombrebdmigrada,proyecto,clavebasedatos,
identificacionarchivo,rutabd,difvalidaciontax,taxonextinto,reinocatvalido,sistemaclasificacionreinocatvalido,divisionphylumcatvalido,sistemaclasificaciondivisionphylumcatvalido,clasecatvalido,
sistemaclasificacionclasecatvalido,autoranioordencatvalido,ordencatvalido,sistemaclasificacionordencatvalido,subordencatvalido,sistemaclasificacionsubordencatvalido,autoraniofamiliacatvalido,
familiacatvalido,sistemaclasificacionfamiliacatvalido,estatusfamiliacatvalido,subfamiliacatvalido,sistemaclasificacionsubfamiliacatvalido,Estatussubfamiliacatvalido,tribucatvalido,sistemaclasificaciontribucatvalido,
estatustribucatvalido,generocatvalido,sistemaclasificaciongenerocatvalido,estatusgenerocatvalido,autoraniogenerocatvalido,subgenerocatvalido,autoraniosubgenerocatvalido,sistemaclasificacionsubgenerocatvalido,
estatussubgenerocatvalido,epitetoespecificocatvalido,catdiccespeciecatvalido,estatusespeciecatvalido,autoranioespeciecatvalido,categoriainfraespeciecatvalido,epitetoinfraespecificocatvalido,catdiccinfraespeciecatvalido,
estatusinfraespeciecatvalido,autoranioinfraespeciecatvalido,categoriainfraespecie2catvalido,epitetoinfraespecifico2catvalido,catdiccinfraespecie2catvalido,estatusinfraespecie2catvalido,autoranioinfraespecie2catvalido,
idnombrecatvalido,cattaxcatvalido,catalogocatvalido,comentarioscatvalido,fuentecatvalido,homonimosgenero,homonimosespecie,homonimosinfraespecie,homonimosgenerocatvalido,homonimosespeciecatvalido,homonimosinfraespeciecatvalido,
ambientenombre,origenambientenombre,formadecrecimiento,gruposcat,hibrido,categoriaoriginalscat,nombreoriginallimpioscat,categoriacatscat,nombrecatscat,estatuscatscat,autoridadcatscat,categoriavalidocatscat,nombrevalidocatscat,
estatusvalidocatscat,autoridadvalidocatscat,ultimafechaactualizacion,fechaactualizacion,version,estadoregistro
from snib.nombre n inner join snib_privadas.nombrecomun using(llavenombre);


alter table snib_privadas.nombre add primary key(llavenombre),add index uno(idnombrecat),
add index dos(comentarioscatvalido),
add index tres(idnombrecatvalido),
add column reftaxvalido_extenso TEXT NOT NULL DEFAULT '' AFTER comentarioscatvalido,
add column anotacionaltaxon varchar(2048) NOT NULL DEFAULT '' AFTER reftaxvalido_extenso;  -- Esta ultima linea se agrego el 03/12/2025 para atender el SNIB2-781

drop table if exists snib_privadas.cita;


-- El 03/12/2025 agregamos los campos idnombrecatvalido
create table snib_privadas.cita
select nt.llavenombre,nt.comentarioscatvalido,n.reinocatvalido,nt.idnombre,idnombrecatvalido
from snib.nombre_taxonomia nt inner join snib_privadas.nombre n using(llavenombre)
where n.comentarioscatvalido like "%Validado completamente con CAT%";

alter table snib_privadas.cita add primary key(llavenombre),add column cita varchar(1012) NOT NULL DEFAULT '',
add index uno(cita(333)),add index dos(comentarioscatvalido(333)), add index tres(idnombre),add index cuatro(reinocatvalido);

update snib_privadas.cita c inner join catalogocentralizado._TransformaTablaNombre_snib t using(idnombre)
inner join catalogocentralizado.RelNombreBiblio r on r.IdNombre=t.idnombrerel
inner join catalogocentralizado.Bibliografia b using(idBibliografia)
set c.cita=b.CitaCompleta
where r.Observaciones like '%eferencia%nom%' or r.Observaciones like '%istema%clasif%';

update snib_privadas.cita
set cita='CONABIO (comp.) 2024. Catálogo de autoridades taxonómicas de especies de flora y fauna con distribución en México. Base de datos SNIB-CONABIO, México.'
where cita='ND' or (cita='' and reinocatvalido<>'');

/* Con este qry solo se actualiza los validados completamente con CAT */
update snib_privadas.nombre n inner join snib_privadas.cita c using(llavenombre)
set n.reftaxvalido_extenso=c.cita;

/* Con este qry solo se actualiza los validados completamente con otra fuente */
update snib_privadas.nombre
set reftaxvalido_extenso='Bánki, O., Roskov, Y., Döring, M., Ower, G., Vandepitte, L., Hobern, D., Remsen, D., Schalk, P., DeWalt, R. E., Keping, M., Miller, J., Orrell, T., Aalbu, R., Adlard, R., Adriaenssens, E. M., Aedo, C., Aescht, E., Akkari, N., Alexander, S., et al. (2022). Catalogue of Life Checklist (Version 2022-12-19). Catalogue of Life. https://www.checklistbank.org/dataset/9854/about'
where comentarioscatvalido like '%completamente con otra fuente%';

-- Agregado el 03/12/2025 para atender el SNIB2-781
-- Primero sacamos los registros validados ocmpletamente con cat candidatos a modificar el campo OtrasObservaciones

drop table if exists snib_privadas.OtrasObservaciones;

create  table snib_privadas.OtrasObservaciones
select distinct idnombrecatvalido
from snib_privadas.cita where idnombrecatvalido is not null and idnombrecatvalido<>'';

alter table snib_privadas.OtrasObservaciones add primary key(idnombrecatvalido);

drop table if exists snib_privadas.OtrasObservaciones_datos;

create table snib_privadas.OtrasObservaciones_datos
select idnombrecatvalido,OtrasObservaciones
from snib_privadas.OtrasObservaciones o inner join catalogocentralizado.SCAT s on o.idnombrecatvalido=s.IdCAT
inner join catalogocentralizado.Nombre n using(IdNombre)
where  n.OtrasObservaciones like '%e acuerdo con%' or n.OtrasObservaciones like '%sin distribución en México%';

alter table snib_privadas.OtrasObservaciones_datos add index (idnombrecatvalido);

-- utilizo la tabla cita que ya se habia creado antes, porque esa tabla solo tiene los registros validados completamente con CAT
update snib_privadas.OtrasObservaciones_datos d inner join snib_privadas.nombre n using(idnombrecatvalido)
set n.anotacionaltaxon = d.OtrasObservaciones
where n.comentarioscatvalido like "%Validado completamente con CAT.%";  -- Este where es para asegurarnos de actualizar solo reg. validads completamente  con CAT.

drop table if exists snib_privadas.cita;

drop table if exists snib_privadas.OtrasObservaciones;

drop table if exists snib_privadas.OtrasObservaciones_datos;

drop table if exists snib_privadas.infogeoportal;

create table snib_privadas.infogeoportal
select n.llavenombre,n.grupo as grupobio,
n.subgrupo as subgrupobio,
n.formadecrecimiento,
n.idnombrecatvalido,
n.idnombrecat,
n.reinocat as reino,
n.divisionphylumcat as phylumdivision,
n.clasecat as clase,
n.ordencat as orden,
case when n.familiacat<>'' then n.familiacat when nol.familiaoriginallimpio not in ('NO DISPONIBLE','',"indet","indet.","auxiliar2","ns","ns1","undet.","unidentified","unknown") then nol.familiaoriginallimpio else '' end as familia,
case when n.generocat<>'' then n.generocat when nol.generooriginallimpio not in ('NO DISPONIBLE','',"indet","indet.","auxiliar2","ns","ns1","undet.","unidentified","unknown") then nol.generooriginallimpio else '' end as genero,
if(n.comentarioscat like '%Validado completamente%',n.nombrecatscat,if(n.comentarioscat like '%Falta validar taxón%',n.nombreoriginallimpioscat,'')) as especie,
case when (n.generocat<>'' or nol.generooriginallimpio not in ('NO DISPONIBLE','',"indet","indet.","auxiliar2","ns","ns1","undet.","unidentified","unknown")) and
(n.epitetoespecificocat not in ('NO DISPONIBLE','')  or nol.epitetoespecificooriginallimpio not in ('NO DISPONIBLE','',"indet","indet.","auxiliar2","ns","ns1","undet.","unidentified","unknown"))
then case when n.categoriainfraespeciecat<>'' then n.categoriainfraespeciecat when nol.categoriainfraespecieoriginal<>'' and nol.epitetoinfraespecificooriginallimpio not in ('NO DISPONIBLE','',"indet","indet.","auxiliar2","ns","ns1","undet.","unidentified","unknown") then nol.categoriainfraespecieoriginal else '' end else '' end as categoriainfraespecie,
case when (n.generocat<>'' or nol.generooriginallimpio not in ('NO DISPONIBLE','',"indet","indet.","auxiliar2","ns","ns1","undet.","unidentified","unknown")) and
(n.epitetoespecificocat not in ('NO DISPONIBLE','')  or nol.epitetoespecificooriginallimpio not in ('NO DISPONIBLE','',"indet","indet.","auxiliar2","ns","ns1","undet.","unidentified","unknown"))
then case when n.categoriainfraespecie2cat<>'' then n.categoriainfraespecie2cat when nol.categoriainfraespecieoriginal2<>'' and nol.epitetoinfraespecificooriginal2limpio not in ('NO DISPONIBLE','',"indet","indet.","auxiliar2","ns","ns1","undet.","unidentified","unknown")then nol.categoriainfraespecieoriginal2 else '' end else '' end as categoriainfraespecie2,
if(n.comentarioscat like '%Validado completamente%',n.autoridadcatscat,'') as autor,
if(n.comentarioscat like '%Validado completamente%',n.estatuscatscat,'') as estatustax,
if(n.comentarioscat like '%completamente con CAT%',t.SistClasCatDiccTaxon,if(n.comentarioscat like '%completamente con otra fuente%','Catalog Of Life Checklist, 2022','')) as reftax,
case when n.comentarioscat like "%completamente%" then 'SI' else 'NO' end as taxonvalidado,
n.reinocatvalido AS reinovalido,
n.divisionphylumcatvalido AS phylumdivisionvalido,
n.clasecatvalido AS clasevalida,
n.ordencatvalido AS ordenvalido,
n.familiacatvalido AS familiavalida,
n.generocatvalido as generovalido,
case when n.generocatvalido not in ('NO DISPONIBLE','') and n.epitetoespecificocatvalido not in ('NO DISPONIBLE','') then
trim(concat(n.generocatvalido,
case when n.subgenerocatvalido not in ('NO DISPONIBLE','') then concat(" (",n.subgenerocatvalido,")") else "" end,
case when n.epitetoinfraespecificocatvalido not in ('NO DISPONIBLE','') then concat(' ',
case when n.epitetoespecificocatvalido in ('NO DISPONIBLE','') then '' else n.epitetoespecificocatvalido end,' ',
case when n.epitetoinfraespecificocatvalido in ('NO DISPONIBLE','') then '' else n.epitetoinfraespecificocatvalido end,' ',n.epitetoinfraespecifico2catvalido)
else concat(' ', case when n.epitetoespecificocatvalido in ('NO DISPONIBLE','') then '' else n.epitetoespecificocatvalido end)end))
else '' end as especievalida,
case when n.categoriainfraespeciecatvalido<>'' then n.categoriainfraespeciecatvalido else '' end as categoriainfraespecievalida,
case when n.categoriainfraespecie2catvalido<>'' then n.categoriainfraespecie2catvalido else '' end as categoriainfraespecie2valida, /*campo nuevo en el geoportal *********************************************************/
case when n.generocatvalido not in ('NO DISPONIBLE','') and n.epitetoespecificocatvalido not in ('NO DISPONIBLE','') then
trim(concat(n.generocatvalido," ",n.epitetoespecificocatvalido)) else "" end as especievalidabusqueda,
case when n.epitetoinfraespecifico2catvalido <>'' then n.autoranioinfraespecie2catvalido 
when n.epitetoinfraespecificocatvalido <>'' then n.autoranioinfraespeciecatvalido when n.epitetoespecificocatvalido <>'' then n.autoranioespeciecatvalido
when n.subgenerocatvalido <>'' then n.autoraniosubgenerocatvalido when n.generocatvalido <>'' then n.autoraniogenerocatvalido
when n.tribucatvalido <>'' then ''
when n.subfamiliacatvalido <>'' then ''
when n.familiacatvalido <>'' then n.autoraniofamiliacatvalido 
when n.subordencatvalido <>'' then ''
when n.ordencatvalido <>'' then n.autoranioordencatvalido else '' end as autorvalido,
case when n.epitetoinfraespecifico2catvalido <>'' then n.catdiccinfraespecie2catvalido
when n.epitetoinfraespecificocatvalido <>'' then n.catdiccinfraespeciecatvalido when n.epitetoespecificocatvalido <>'' then n.catdiccespeciecatvalido
when n.subgenerocatvalido <>'' then n.sistemaclasificacionsubgenerocatvalido 
when n.generocatvalido <>'' then n.sistemaclasificaciongenerocatvalido 
when n.tribucatvalido <>'' then n.sistemaclasificaciontribucatvalido
when n.subfamiliacatvalido <>'' then n.sistemaclasificaciontribucatvalido
when n.familiacatvalido <>'' then n.sistemaclasificacionfamiliacatvalido 
when n.subordencatvalido <>'' then n.sistemaclasificacionsubordencatvalido
when n.ordencatvalido <>'' then n.sistemaclasificacionordencatvalido 
when n.clasecatvalido <>'' then n.sistemaclasificacionclasecatvalido
when n.divisionphylumcatvalido <>'' then n.sistemaclasificaciondivisionphylumcatvalido
when n.reinocatvalido <>'' then n.sistemaclasificacionreinocatvalido  else '' end as reftaxvalido,
/* case when n.epitetoinfraespecifico2catvalido <>'' then n.autoranioinfraespecie2catvalido 
when n.epitetoinfraespecificocatvalido <>'' then n.autoranioinfraespeciecatvalido when n.epitetoespecificocatvalido <>'' then n.autoranioespeciecatvalido
when n.subgenerocatvalido <>'' then n.autoraniosubgenerocatvalido when n.generocatvalido <>'' then n.autoraniogenerocatvalido else '' end as autorvalido,
case when n.epitetoinfraespecifico2catvalido <>'' then n.catdiccinfraespecie2catvalido
when n.epitetoinfraespecificocatvalido <>'' then n.catdiccinfraespeciecatvalido when n.epitetoespecificocatvalido <>'' then n.catdiccespeciecatvalido
when n.subgenerocatvalido <>'' then n.sistemaclasificacionsubgenerocatvalido
when n.generocatvalido <>'' then n.sistemaclasificaciongenerocatvalido when n.familiacatvalido <>'' then n.sistemaclasificacionfamiliacatvalido else '' end as reftaxvalido,*/
if(n.comentarioscat like '%Validado completamente%',n.categoriacatscat,if(n.comentarioscat like '%Falta validar taxón%',n.categoriaoriginalscat,'')) as categoriataxonomica,
n.categoriavalidocatscat,
n.nombrevalidocatscat,
n.epitetoespecificocatvalido,
n.epitetoinfraespecificocatvalido,
n.epitetoinfraespecifico2catvalido,
nc.nombrecomun,
nc.nombrecomun_es,
comentarioscat,
comentarioscatvalido,
reftaxvalido_extenso,
anotacionaltaxon
from snib_privadas.nombre n inner join snib.nombreoriginallimpio nol using(llavenombre)
inner join catalogocentralizado._TransformaTablaNombre t on n.idnombrecat=t.IdCAT
inner join snib_privadas.nombrecomun nc using(llavenombre);

alter table snib_privadas.infogeoportal add primary key(llavenombre);

update snib_privadas.infogeoportal
set especie='',
autor='',
estatustax=''
where especie not like '% %' or especie='No asignado' or (especie like "%incertae%sedis%" and categoriataxonomica<>'especie');

update snib_privadas.infogeoportal
set categoriataxonomica=''
where especie='';


-- antes de actualizar sacamosun respaldo por si hay falla

-- Se quito la creación de la tabla y se programo un respaldo de la tabla, porque el generar la copia de la tabla era muy tardado. (2024-08-29)

/*
drop table if exists snib_privadas.ejemplar_nombre_info_respaldo;

 create table snib_privadas.ejemplar_nombre_info_respaldo
select distinct llavenombre,grupobio,subgrupobio,reino,phylumdivision,clase,orden,familia,genero,especie,categoriainfraespecie,categoriainfraespecie2,autor,estatustax,reftax,taxonvalidado,reinovalido,phylumdivisionvalido,
clasevalida,ordenvalido,familiavalida,generovalido,especievalida,especievalidabusqueda,epitetoespecificocatvalido,epitetoinfraespecificocatvalido,epitetoinfraespecifico2catvalido,
categoriainfraespecievalida,categoriainfraespecie2valida,autorvalido,reftaxvalido,categoriavalidocatscat,nombrevalidocatscat,nombrecomun,nombrecomun_es,formadecrecimiento,idnombrecatvalido,idnombrecat,comentarioscat,comentarioscatvalido,reftaxvalido_extenso,now() as fecharespaldo
from snib_privadas.ejemplar_nombre en inner join snib_privadas.informaciongeoportal_consultas using(idejemplar); */

update snib_privadas.informaciongeoportal_consultas i inner join snib_privadas.ejemplar_nombre e using(idejemplar)
inner join snib_privadas.infogeoportal ig using(llavenombre)
set i.grupobio=ig.grupobio,
i.subgrupobio=ig.subgrupobio,
i.reino=ig.reino,
i.phylumdivision=ig.phylumdivision,
i.clase=ig.clase,
i.orden=ig.orden,
i.familia=ig.familia,
i.genero=ig.genero,
i.especie=ig.especie,
i.categoriainfraespecie=ig.categoriainfraespecie,
i.categoriainfraespecie2=ig.categoriainfraespecie2,
i.autor=ig.autor,
i.estatustax=ig.estatustax,
i.reftax=ig.reftax,
i.taxonvalidado=ig.taxonvalidado,
i.reinovalido=ig.reinovalido,
i.phylumdivisionvalido=ig.phylumdivisionvalido,
i.clasevalida=ig.clasevalida,
i.ordenvalido=ig.ordenvalido,
i.familiavalida=ig.familiavalida,
i.generovalido=ig.generovalido,
i.especievalida=ig.especievalida,
i.especievalidabusqueda=ig.especievalidabusqueda,
i.epitetoespecificocatvalido=ig.epitetoespecificocatvalido,
i.epitetoinfraespecificocatvalido=ig.epitetoinfraespecificocatvalido,
i.epitetoinfraespecifico2catvalido=ig.epitetoinfraespecifico2catvalido,
i.categoriainfraespecievalida=ig.categoriainfraespecievalida,
i.categoriainfraespecie2valida=ig.categoriainfraespecie2valida,
i.autorvalido=ig.autorvalido,
i.reftaxvalido=ig.reftaxvalido,
i.categoriavalidocatscat=ig.categoriavalidocatscat,
i.nombrevalidocatscat=ig.nombrevalidocatscat,
-- i.nombrevalido_cuentas_sib=if(ig.nombrevalidocatscat like "% % %" and replace(SUBSTRING_INDEX(ig.nombrevalidocatscat, ' ', -2),SUBSTRING_INDEX(ig.nombrevalidocatscat, ' ', -1),'')=' ',REGEXP_REPLACE(ig.nombrevalidocatscat, " [a-z]+$", ''),ig.nombrevalidocatscat),
i.nombrecomun=ig.nombrecomun,
i.nombrecomun_es=ig.nombrecomun_es,
i.formadecrecimiento=ig.formadecrecimiento,
i.idnombrecatvalido=ig.idnombrecatvalido,
i.idnombrecat=ig.idnombrecat,
i.comentarioscat=ig.comentarioscat,
i.comentarioscatvalido=ig.comentarioscatvalido,
i.reftaxvalido_extenso=ig.reftaxvalido_extenso,
i.anotacionaltaxon=ig.anotacionaltaxon;

/*
SELECT distinct nombrevalidocatscat,nombrevalido_cuentas_sib,REGEXP_REPLACE(nombrevalidocatscat, " [a-z]+$", '') as tres,
SUBSTRING_INDEX(nombrevalidocatscat, ' ', -1) as uno,
SUBSTRING_INDEX(nombrevalidocatscat, ' ', -2) as dos
FROM snib_privadas.informaciongeoportal_consultas
where nombrevalidocatscat like "% % %" and replace(SUBSTRING_INDEX(nombrevalidocatscat, ' ', -2),SUBSTRING_INDEX(nombrevalidocatscat, ' ', -1),'')=' ';
*/

-- Primero limpiamos todas las categorias de riesgo
-- Esto se haría solo en los ejemplares donde hubo cambios en nombre. a partir de la tabla ejemplar_nombre
drop table if exists snib_privadas.informaciongeoportal_consultas_corte;

create table snib_privadas.informaciongeoportal_consultas_corte
select idejemplar,categoriaresidenciaaves,prioritaria,nivelprioridad,exoticainvasora,endemismo,iucn,nom059,cites,tiporestriccion
from snib_privadas.informaciongeoportal_consultas i inner join snib_privadas.ejemplar_nombre e using(idejemplar);

alter table snib_privadas.informaciongeoportal_consultas_corte add index uno(idejemplar),add index dos(tiporestriccion);

UPDATE snib_privadas.informaciongeoportal_consultas_corte
set categoriaresidenciaaves='',
prioritaria='',
nivelprioridad='',
exoticainvasora='',
endemismo='',
iucn='',
nom059='',
cites=''
where tiporestriccion<>'Restringido. Registro con coordenadas privadas.';

-- Actualizamos categorias de riesgo
UPDATE snib_privadas.informaciongeoportal_consultas_corte e INNER JOIN snib.ejemplarcategoriariesgo ecr on e.idejemplar=ecr.llaveejemplar
inner join snib.categoriasproteccion c on ecr.idcategoriaresidenciaaves=c.idcategoriaproteccion
set e.categoriaresidenciaaves= if(tiporestriccion<>'Restringido. Registro con coordenadas privadas.',c.categoria,e.categoriaresidenciaaves) -- con esta linea no actualizamos las coordenadas privadas
where c.lista='residenciaaves';

UPDATE snib_privadas.informaciongeoportal_consultas_corte e INNER JOIN snib.ejemplarcategoriariesgo ecr on e.idejemplar=ecr.llaveejemplar
inner join snib.categoriasproteccion c on ecr.idprioritarias=c.idcategoriaproteccion
set e.prioritaria=if(tiporestriccion<>'Restringido. Registro con coordenadas privadas.',c.categoria,e.prioritaria), -- con esta linea no actualizamos las coordenadas privadas,
e.nivelprioridad=if(tiporestriccion<>'Restringido. Registro con coordenadas privadas.',ecr.nivelprioridad,e.nivelprioridad) -- con esta linea no actualizamos las coordenadas privadas
where c.lista='prioritarias';

UPDATE snib_privadas.informaciongeoportal_consultas_corte e INNER JOIN snib.ejemplarcategoriariesgo ecr on e.idejemplar=ecr.llaveejemplar
inner join snib.categoriasproteccion c on ecr.idestatusinvasora=c.idcategoriaproteccion
set e.exoticainvasora=if(tiporestriccion<>'Restringido. Registro con coordenadas privadas.',c.categoria,e.exoticainvasora) -- con esta linea no actualizamos las coordenadas privadas
where c.lista='estatusinvasora';

UPDATE snib_privadas.informaciongeoportal_consultas_corte e INNER JOIN snib.ejemplarcategoriariesgo ecr on e.idejemplar=ecr.llaveejemplar
inner join snib.categoriasproteccion c on ecr.idendemismo=c.idcategoriaproteccion
set e.endemismo=if(tiporestriccion<>'Restringido. Registro con coordenadas privadas.',c.categoria,e.endemismo) -- con esta linea no actualizamos las coordenadas privadas
where c.lista='endemismo';

-- UPDATE snib_privadas.informaciongeoportal_consultas e INNER JOIN snib.ejemplarIUCN i on e.idejemplar=i.llaveejemplar
-- set e.iucn=if(tiporestriccion<>'Restringido. Registro con coordenadas privadas.',i.iucnsinobservaciones,e.IUCN);

-- Actualizada la sig consulta el 08/12/2025 porque la anterior tardaba 6 hrs y la de abajo 1 hora
UPDATE snib_privadas.informaciongeoportal_consultas_corte e INNER JOIN snib.ejemplarIUCN i on e.idejemplar=i.llaveejemplar
set e.iucn=if(tiporestriccion<>'Restringido. Registro con coordenadas privadas.',if(e.IUCN<>i.iucnsinobservaciones,i.iucnsinobservaciones,e.IUCN),e.IUCN); -- con esta linea no actualizamos las coordenadas privadas;

UPDATE snib_privadas.informaciongeoportal_consultas_corte e INNER JOIN snib.ejemplarNOM i on e.idejemplar=i.llaveejemplar
set e.nom059=if(tiporestriccion<>'Restringido. Registro con coordenadas privadas.',i.nomsinobservaciones,e.nom059); -- con esta linea no actualizamos las coordenadas privadas

UPDATE snib_privadas.informaciongeoportal_consultas_corte e INNER JOIN snib.ejemplarCITES i on e.idejemplar=i.llaveejemplar
set e.cites=if(tiporestriccion<>'Restringido. Registro con coordenadas privadas.',i.citessinobservaciones,e.cites); -- con esta linea no actualizamos las coordenadas privadas

UPDATE snib_privadas.informaciongeoportal_consultas_corte i inner join snib_privadas.informaciongeoportal_consultas ic using(idejemplar)
set ic.categoriaresidenciaaves=i.categoriaresidenciaaves,
ic.prioritaria=i.prioritaria,
ic.nivelprioridad=i.nivelprioridad,
ic.exoticainvasora=i.exoticainvasora,
ic.endemismo=i.endemismo,
ic.iucn=i.iucn,
ic.nom059=i.nom059,
ic.cites=i.cites;

-- mandamos a llamar el procedimiento que actualiza los registros de coordenafas privadas.
call snib_privadas.2_1_ActualizaInfoadicional_coord_privadas();
INSERT INTO dwh.ValidaProcesosAutomaticos(Nombre_SP, TipoError, Mensaje)
   								  VALUES ('snib_privadas.01_Actualiza_ig_consultas', 
	    								  'Info', 
	    								  'El proceso se termino con exito' );

SELECT 'Termino';
END $$

DELIMITER ;
