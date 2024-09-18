DROP TABLE AUDITORIA;

CREATE TABLE AUDITORIA (
    ID_AUDITORIA NUMBER PRIMARY KEY,
    TIPO_CAMBIO VARCHAR2(50),
    FECHA_CAMBIO DATE,
    DETALLE VARCHAR2(400),
    ATRIBUTO_ANTERIOR VARCHAR2(100), -- Nullable
    ATRIBUTO_NUEVO VARCHAR2(100)     -- Nullable
);   

DROP SEQUENCE seq_auditoria_id;

CREATE SEQUENCE seq_auditoria_id
START WITH 1
INCREMENT BY 1;

-------------------------------------------------------------------------------
-- 4.C.i
CREATE OR REPLACE FUNCTION calc_Edad 
RETURN NUMBER 
IS
    v_fecha_nacimiento DATE;
    v_edad NUMBER;
BEGIN
    BEGIN
        SELECT FECHA_NACIMIENTO 
        INTO v_fecha_nacimiento 
        FROM PACIENTE 
        WHERE ROWNUM = 1; 
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_fecha_nacimiento := NULL;
    END;

    IF v_fecha_nacimiento IS NOT NULL THEN
        v_edad := TRUNC(MONTHS_BETWEEN(SYSDATE, v_fecha_nacimiento) / 12);
        
        INSERT INTO AUDITORIA (ID_AUDITORIA, TIPO_CAMBIO, FECHA_CAMBIO, DETALLE)
        VALUES (seq_auditoria_id.NEXTVAL, 
                'Calcular edad', 
                SYSDATE, 
                'Edad del primer paciente es: ' || v_edad);
        COMMIT;
    ELSE
        v_edad := NULL;
        
        INSERT INTO AUDITORIA (ID_AUDITORIA, TIPO_CAMBIO, FECHA_CAMBIO, DETALLE)
        VALUES (seq_auditoria_id.NEXTVAL, 
                'Calcular edad', 
                SYSDATE, 
                'No se encontró el primer paciente.');
        COMMIT;
    END IF;

    RETURN v_edad;
END;

DECLARE
    edad NUMBER;
BEGIN
    edad := calc_Edad;
    DBMS_OUTPUT.PUT_LINE('----------------------------------------');
    DBMS_OUTPUT.PUT_LINE('La edad del primer paciente es: ' || edad);
    DBMS_OUTPUT.PUT_LINE('----------------------------------------');
END;

-------------------------------------------------------------------------------
-- 4.C.ii
CREATE OR REPLACE FUNCTION ver_Pac(
    p_pac_run PACIENTE.PAC_RUN%TYPE,
    p_dv_run PACIENTE.DV_RUN%TYPE
) RETURN VARCHAR2
IS
    v_count NUMBER;
    v_nombre_paciente VARCHAR2(255);
    v_rut_paciente VARCHAR2(20);
    v_fecha_nacimiento PACIENTE.FECHA_NACIMIENTO%TYPE;
    v_telefono_paciente PACIENTE.TELEFONO%TYPE;
    v_resultado VARCHAR2(500);
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM PACIENTE
    WHERE PAC_RUN = p_pac_run
      AND DV_RUN = p_dv_run;

    IF v_count > 0 THEN
        SELECT 
            PNOMBRE || ' ' || APATERNO || ' ' || AMATERNO AS nombre_paciente,
            PAC_RUN || '-' || DV_RUN AS rut_paciente,
            FECHA_NACIMIENTO,
            TELEFONO
        INTO 
            v_nombre_paciente,
            v_rut_paciente,
            v_fecha_nacimiento,
            v_telefono_paciente
        FROM PACIENTE
        WHERE PAC_RUN = p_pac_run
          AND DV_RUN = p_dv_run;

        v_resultado := 'Nombre Paciente: ' || v_nombre_paciente || CHR(10) ||
                       'Rut Paciente: ' || v_rut_paciente || CHR(10) ||
                       'Fecha de Nacimiento: ' || TO_CHAR(v_fecha_nacimiento, 'DD/MM/YYYY') || CHR(10);

        INSERT INTO AUDITORIA (ID_AUDITORIA, TIPO_CAMBIO, FECHA_CAMBIO, DETALLE, ATRIBUTO_ANTERIOR, ATRIBUTO_NUEVO)
        VALUES (seq_auditoria_id.NEXTVAL,
            'Verificar Paciente',
            SYSDATE,
            'RUT del paciente: ' || v_rut_paciente,
            NULL,  
            NULL  
        );
    ELSE
        v_resultado := 'Paciente no esta registrado.';

    END IF;

    RETURN v_resultado;
END;

DECLARE
    v_resultado VARCHAR2(500);
BEGIN
    v_resultado := ver_Pac(6215470, '5'); 
    DBMS_OUTPUT.PUT_LINE('----------------------------------------');
    DBMS_OUTPUT.PUT_LINE(v_resultado);
    DBMS_OUTPUT.PUT_LINE('----------------------------------------');
END;


-------------------------------------------------------------------------------
-- 4.C.iii
CREATE OR REPLACE PROCEDURE up_Sueldo
IS
BEGIN
    UPDATE MEDICO
    SET SUELDO_BASE = SUELDO_BASE * 1.10;
    
    COMMIT;   
    DBMS_OUTPUT.PUT_LINE('Sueldo aumento en 10% para todo médicos.');
END;

CREATE OR REPLACE TRIGGER trg_up_Sueldo
AFTER UPDATE OF SUELDO_BASE ON MEDICO
FOR EACH ROW
BEGIN
    INSERT INTO AUDITORIA (ID_AUDITORIA, TIPO_CAMBIO, FECHA_CAMBIO, DETALLE, ATRIBUTO_ANTERIOR, ATRIBUTO_NUEVO)
    VALUES (
        seq_auditoria_id.NEXTVAL,
        'Actualiza Sueldo Medico',
        SYSDATE,
        'Se actualizó el sueldo del médico RUN: ' || :OLD.MED_RUN,
        :OLD.SUELDO_BASE,
        :NEW.SUELDO_BASE
    );
END;

BEGIN
    up_Sueldo;
END;

-------------------------------------------------------------------------------
-- 4.C.iv
DROP SEQUENCE seq_ate_id;

CREATE SEQUENCE seq_ate_id
START WITH 6000 
INCREMENT BY 1;

CREATE OR REPLACE PROCEDURE reg_att (
    p_fecha_atencion IN DATE,
    p_hr_atencion IN VARCHAR2,
    p_costo IN NUMBER,
    p_med_run IN NUMBER,
    p_esp_id IN NUMBER,
    p_pac_run IN NUMBER
) IS
    v_ate_id NUMBER;
BEGIN
    SELECT seq_ate_id.NEXTVAL INTO v_ate_id FROM dual;

    INSERT INTO atencion (ate_id, fecha_atencion, hr_atencion, costo, med_run, esp_id, pac_run)
    VALUES (v_ate_id, p_fecha_atencion, p_hr_atencion, p_costo, p_med_run, p_esp_id, p_pac_run);

    COMMIT;
END;

CREATE OR REPLACE TRIGGER trg_registro_atencion
AFTER INSERT ON ATENCION
FOR EACH ROW
BEGIN
    INSERT INTO AUDITORIA (
        ID_AUDITORIA, 
        TIPO_CAMBIO, 
        FECHA_CAMBIO, 
        DETALLE, 
        ATRIBUTO_ANTERIOR, 
        ATRIBUTO_NUEVO
    )
    VALUES (
        seq_auditoria_id.NEXTVAL,
        'Registro de Atencion',
        SYSDATE,
        'ID del registro de atencion: ' || :NEW.ATE_ID,
        NULL,
        NULL
    );

END;

BEGIN
    reg_att(
        p_fecha_atencion => TO_DATE('2024-09-08', 'YYYY-MM-DD'),
        p_hr_atencion => '10:00',
        p_costo => 15000,
        p_med_run => 6117105,
        p_esp_id => 200,
        p_pac_run => 1105913
    );
END;
