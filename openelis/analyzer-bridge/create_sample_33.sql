BEGIN;

DO $$
DECLARE
  next_person numeric;
  next_patient numeric;
  next_sample numeric;
  next_sample_human numeric;
  next_sample_item numeric;
  next_analysis numeric;
  t record;
  i int := 0;
BEGIN
  IF EXISTS (SELECT 1 FROM sample WHERE accession_number = '33') THEN
    RAISE NOTICE 'Sample 33 already exists';
    RETURN;
  END IF;

  SELECT COALESCE(MAX(id),0)+1 INTO next_person FROM person;
  SELECT COALESCE(MAX(id),0)+1 INTO next_patient FROM patient;
  SELECT COALESCE(MAX(id),0)+1 INTO next_sample FROM sample;
  SELECT COALESCE(MAX(id),0)+1 INTO next_sample_human FROM sample_human;
  SELECT COALESCE(MAX(id),0)+1 INTO next_sample_item FROM sample_item;
  SELECT COALESCE(MAX(id),0)+1 INTO next_analysis FROM analysis;

  INSERT INTO person (id, first_name, last_name, lastupdated)
  VALUES (next_person, 'Sysmex', 'TestPatient', now());

  INSERT INTO patient (id, person_id, gender, birth_date, national_id, lastupdated)
  VALUES (next_patient, next_person, 'M', '1990-01-01', 'XN350-33', now());

  INSERT INTO sample (
    id, accession_number, domain, entered_date, received_date, collection_date,
    sys_user_id, lastupdated, status_id, is_confirmation, fhir_uuid, order_priority, nidan_visit_type
  ) VALUES (
    next_sample, '33', 'H', CURRENT_DATE, now(), now(),
    1, now(), 1, false, gen_random_uuid(), 'ROUTINE', 'OPD Visit'
  );

  INSERT INTO sample_human (id, samp_id, patient_id, provider_id, lastupdated)
  VALUES (next_sample_human, next_sample, next_patient, 2, now());

  INSERT INTO sample_item (
    id, samp_id, typeosamp_id, sort_order, status_id, lastupdated, external_id, fhir_uuid
  ) VALUES (
    next_sample_item, next_sample, 4, 1, 20, now(), '33', gen_random_uuid()
  );

  FOR t IN
    SELECT * FROM (VALUES
      (487::numeric, 187::numeric),
      (488, 187),
      (496, 187),
      (490, 187),
      (486, 187),
      (485, 187),
      (484, 187),
      (489, 187),
      (545, 187),
      (546, 187),
      (543, 187),
      (443, 36),
      (544, 187)
    ) AS x(tid, sect)
  LOOP
    INSERT INTO analysis (
      id, sampitem_id, test_sect_id, test_id, analysis_type, status_id,
      entry_date, lastupdated, fhir_uuid, is_reportable
    ) VALUES (
      next_analysis + i, next_sample_item, t.sect, t.tid, 'MANUAL', 4,
      now(), now(), gen_random_uuid(), 'Y'
    );
    i := i + 1;
  END LOOP;

  IF EXISTS (SELECT 1 FROM pg_class WHERE relname='person_seq') THEN
    PERFORM setval('person_seq', (SELECT MAX(id)::bigint FROM person));
  END IF;
  IF EXISTS (SELECT 1 FROM pg_class WHERE relname='patient_seq') THEN
    PERFORM setval('patient_seq', (SELECT MAX(id)::bigint FROM patient));
  END IF;
  IF EXISTS (SELECT 1 FROM pg_class WHERE relname='sample_seq') THEN
    PERFORM setval('sample_seq', (SELECT MAX(id)::bigint FROM sample));
  END IF;
  IF EXISTS (SELECT 1 FROM pg_class WHERE relname='sample_human_seq') THEN
    PERFORM setval('sample_human_seq', (SELECT MAX(id)::bigint FROM sample_human));
  END IF;
  IF EXISTS (SELECT 1 FROM pg_class WHERE relname='sample_item_seq') THEN
    PERFORM setval('sample_item_seq', (SELECT MAX(id)::bigint FROM sample_item));
  END IF;
  IF EXISTS (SELECT 1 FROM pg_class WHERE relname='analysis_seq') THEN
    PERFORM setval('analysis_seq', (SELECT MAX(id)::bigint FROM analysis));
  END IF;

  RAISE NOTICE 'Created sample 33 with % analyses', i;
END $$;

COMMIT;

SELECT s.id, s.accession_number, s.status_id, count(a.id) AS analyses
FROM sample s
JOIN sample_item si ON si.samp_id = s.id
JOIN analysis a ON a.sampitem_id = si.id
WHERE s.accession_number = '33'
GROUP BY s.id, s.accession_number, s.status_id;

SELECT t.name
FROM analysis a
JOIN sample_item si ON si.id = a.sampitem_id
JOIN sample s ON s.id = si.samp_id
JOIN test t ON t.id = a.test_id
WHERE s.accession_number = '33'
ORDER BY t.name;
