## LOAD NIH ICITE2.0 DATA
## LOAD METADATA

CREATE TABLE temp_icite (
    pmid INT UNSIGNED,
    doi VARCHAR(100),
    title TEXT,
    authors TEXT,
    pubyr MEDIUMINT,
    jnl_short VARCHAR(150),
    is_art VARCHAR(5),
    ncited MEDIUMINT,
    fcr DOUBLE,
    ecpy DOUBLE,
    cpy DOUBLE,
    rcr DOUBLE,
    nihpctl DOUBLE,
    human DOUBLE,
    animal DOUBLE,
    molcell DOUBLE,
    x_ach DOUBLE,
    y_ach DOUBLE,
    apt DOUBLE,
    is_clin VARCHAR(5),
    clin_cites TEXT,
    cites TEXT,
    refs TEXT,
    INDEX (pmid)
);

LOAD data INFILE "F:/icite_metadata.csv" IGNORE INTO TABLE temp_icite
fields TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n';

DELETE FROM temp_icite 
WHERE
    pmid = 0;

CREATE TABLE temp00 (
    pmid INT UNSIGNED,
    cited INT UNSIGNED
);

load data INFILE "F:/open_citation_collection.csv" IGNORE INTO TABLE temp00
fields TERMINATED BY ',';

CREATE INDEX temp00id
ON temp00
             (
                          pmid
             );
             
DELETE FROM temp00 
WHERE
    pmid = 0;

CREATE TABLE temp01 AS SELECT t.pmid, pubyr, cited FROM
    temp00 AS t
        LEFT JOIN
    temp_icite AS i ON i.pmid = t.pmid;

CREATE INDEX temp01id
ON temp01
             (
                          cited
             );

CREATE TABLE temp02 AS SELECT t.*, i.pubyr AS citedyr FROM
    temp01 AS t
        LEFT JOIN
    temp_icite AS i ON i.pmid = t.cited;

CREATE INDEX temp02id1
ON temp02
             (
                          pmid,
                          cited
             );

CREATE INDEX temp02id2
ON temp02
             (
                          cited
             );

SET SQL_SAFE_UPDATES = 0;
DELETE FROM temp02 
WHERE
    cited = pmid;
SET SQL_SAFE_UPDATES = 1;

CREATE TABLE pmid_2206_nref AS SELECT pmid, COUNT(*) AS nref, 'OCC' AS occ FROM
    temp02
GROUP BY pmid;

CREATE INDEX pmid_2206_nrefid
ON pmid_2206_nref
             (
                          pmid
             );

CREATE TABLE pmid_2206_icite (
    pmid INT UNSIGNED,
    doi VARCHAR(100),
    title TEXT,
    authors TEXT,
    pubyr MEDIUMINT,
    jnl_short VARCHAR(150),
    is_art VARCHAR(5),
    occ VARCHAR(5),
    nref MEDIUMINT,
    ncited MEDIUMINT,
    fcr DOUBLE,
    ecpy DOUBLE,
    cpy DOUBLE,
    rcr DOUBLE,
    nihpctl DOUBLE,
    human DOUBLE,
    animal DOUBLE,
    molcell DOUBLE,
    x_ach DOUBLE,
    y_ach DOUBLE,
    apt DOUBLE,
    is_clin VARCHAR(5),
    clin_cites TEXT,
    INDEX (pmid)
);

INSERT INTO pmid_2206_icite
SELECT    t.pmid,
          doi,
          title,
          authors,
          pubyr,
          jnl_short,
          is_art,
          occ,
          nref,
          ncited,
          fcr,
          ecpy,
          cpy,
          rcr,
          nihpctl,
          human,
          animal,
          molcell,
          x_ach,
          y_ach,
          apt,
          is_clin,
          clin_cites
FROM      temp_icite     AS t
LEFT JOIN pmid_2206_nref AS p
ON        p.pmid=t.pmid;

UPDATE pmid_2206_icite 
SET 
    nref = 0
WHERE
    (nref IS NULL AND pmid <> 0);

DROP TABLE temp_icite;
DROP TABLE  pmid_2206_nref;

CREATE TABLE temp03 AS SELECT pmid AS cited, clin_cites FROM
    pmid_2206_icite
WHERE
    clin_cites <> '';

CREATE INDEX temp03id
ON temp03
             (
                          cited
             );

# Warning, temp04 takes a long time to create ~45 hours
CREATE TABLE temp04 AS SELECT pmid, c.cited, clin_cites FROM
    temp02 AS c,
    temp03 AS t
WHERE
    t.cited = c.cited;

CREATE TABLE temp05 AS SELECT * FROM
    temp04
WHERE
    LOCATE(pmid, clin_cites) > 0;

SET SQL_SAFE_UPDATES = 0;
UPDATE temp05 
SET 
    clin_cites = 'CLIN';
SET SQL_SAFE_UPDATES = 1;

CREATE INDEX temp05id1
ON temp05
             (
                          pmid,
                          cited
             );

CREATE TABLE temp06 (
    pmid INT UNSIGNED,
    pubyr MEDIUMINT,
    cited INT UNSIGNED,
    citedyr MEDIUMINT,
    clin VARCHAR(5)
);

INSERT INTO temp06
SELECT    p.*,
          clin_cites
FROM      temp02 AS p
LEFT JOIN temp05 AS t
ON        t.pmid=p.pmid
AND       t.cited=p.cited;

create index temp06id on temp06(pmid);

drop table temp00;
drop table temp01;
drop table temp02;
drop table temp03;
drop table temp04;
drop table temp05;

## LIST OF CLINICAL PAPERS

create table pmid_2202_clin as select pmid, count(*) AS nref from temp06 where clin='CLIN' group by pmid;
create index pmid_2202_clinid on pmid_2202_clin(pmid);

alter table temp06 rename pmid_2202_cited;
create index pmid_2202_citedid on pmid_2202_cited(cited);

## GET LIST OF NEW PMID FOR WHICH METADATA IS NEEDED

create database pmmod2202;
use pmmod2202;

create table pmid_new as select a.pmid, a.pubyr from icite.pmid_2202_icite AS a left join icite.pmid_2104_icite AS b
 on b.pmid=a.pmid where b.pmid is null;
create index pmid_newid on pmid_new(pmid);

# OUTPUT RESULTS
select * into outfile "C:/SciTech/Projects/PMmodel/03_update2202/pmid_new.txt" from pmid_new; 