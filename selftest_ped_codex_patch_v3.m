function result = selftest_ped_codex_patch_v3(patch_root)
% SELFTEST_PED_CODEX_PATCH_V3  Fast tests; no neural network is trained.
if nargin<1 || isempty(patch_root); patch_root=fileparts(mfilename('fullpath')); end
addpath(genpath(patch_root));
pass=0; total=0;

check('depth segmentation detects one physical gap',@test_segments);
check('CNN fit is fail-closed without segment IDs',@test_fit_fail_closed);
check('canonical HP precedes corrected Gate 9',@test_gate_order);
check('Phase 1 contains no hard-coded Direct Ridge metric',@test_no_hardcode);
check('Phase 2 contains no post-freeze movefile',@test_no_move);
check('all patched base-model calls pass segment IDs',@test_calls);
check('provenance distinguishes fixed-HP and full reanalysis',@test_provenance);
check('Gate 17 closes files and verifies the final manifest',@test_gate17_order);
check('manifest verifier detects post-manifest mutation',@test_manifest_mutation);
fprintf('PED Codex patch v3 self-test: %d/%d PASS\n',pass,total);
assert(pass==total,'selftest_ped_codex_patch_v3: one or more tests failed');
result=struct('n_pass',pass,'n_total',total,'status','PASS');

    function check(label,fn)
        total=total+1;
        try; fn(); pass=pass+1; fprintf('[PASS] %s\n',label);
        catch ME; fprintf('[FAIL] %s: %s\n',label,ME.message); end
    end
    function test_segments
        cfg=struct(); d=[100;100.1;100.2;101.0;101.1];
        s=nrr_data.depth_segment_ids(d,cfg);
        assert(isequal(s,[1;1;1;2;2]));
    end
    function test_fit_fail_closed
        hp=struct();cfg=struct();did_fail=false;
        try; nrr_models.fit_cnn1d(zeros(20,4),zeros(20,1),hp,42,cfg); %#ok<NASGU>
        catch ME; did_fail=contains(ME.message,'mandatory'); end
        assert(did_fail);
    end
    function test_gate_order
        s=fileread(fullfile(patch_root,'main_nrr_pipeline.m'));
        assert(strfind(s,'gate10_canonical_hp') < strfind(s,'gate9_provenance')); %#ok<STRIFCND>
        g=fileread(fullfile(patch_root,'+nrr_eval','gate9_provenance.m'));
        assert(contains(g,'hp=run.canon_hp') && ~contains(g,'fold_hp{end}'));
    end
    function test_no_hardcode
        s=fileread(fullfile(patch_root,'run_ped_corrected_pipeline.m'));
        assert(~contains(s,'[corrected_holdout_r2; -3.0622; 0.4089]'));
        assert(contains(s,'run_p1.hist.direct_ridge'));
    end
    function test_no_move
        s=fileread(fullfile(patch_root,'run_ped_corrected_pipeline.m'));
        assert(~contains(s,'movefile('));
    end
    function test_calls
        active={fullfile('+nrr_models','fit_base_set.m'), ...
            fullfile('+nrr_models','generate_inner_oof.m'), ...
            fullfile('+nrr_models','tune_inner_stacked.m'), ...
            fullfile('+nrr_eval','run_nested_cv.m'), ...
            fullfile('+nrr_eval','fit_frozen_deployment.m'), ...
            fullfile('+nrr_eval','predict_frozen_deployment.m'), ...
            fullfile('+nrr_eval','gate9_provenance.m')};
        alltext='';
        for ii=1:numel(active)
            alltext=[alltext newline fileread(fullfile(patch_root,active{ii}))]; %#ok<AGROW>
        end
        assert(~contains(alltext,'fit_cnn1d(X,y,hp_cn,seeds.cnn1d,cfg);'));
        assert(contains(alltext,'cfg,segment_ids)'));
        assert(contains(alltext,'predict_base_set(deploy.base_nets,X_B,seg_B)'));
    end
    function test_provenance
        s=fileread(fullfile(patch_root,'run_ped_corrected_pipeline.m'));
        assert(contains(s,'PED_CORRECTED_FIXED_HP_EXTENSION'));
        assert(contains(s,'PED_CORRECTED_FULL_REANALYSIS'));
    end
    function test_gate17_order
        s=fileread(fullfile(patch_root,'+nrr_eval','gate17_geomech_freeze.m'));
        p_close=strfind(s,'close_status=fclose(fid)');
        p_pass=strfind(s,"run.gate.GATE_17 = 'PASS'");
        p_save=strfind(s,"save(fullfile(out8,'FROZEN_NUMERICAL_RUN.mat')");
        p_manifest=strfind(s,'compute_sha256_manifest');
        p_verify=strfind(s,'verify_sha256_manifest');
        assert(isscalar(p_close) && isscalar(p_pass) && isscalar(p_save));
        assert(isscalar(p_manifest) && isscalar(p_verify));
        assert(p_close<p_pass && p_pass<p_save && p_save<p_manifest && p_manifest<p_verify);
        assert(isempty(strfind(s(p_manifest:end),...
            "save(fullfile(out8,'FROZEN_NUMERICAL_RUN.mat')"))); %#ok<STREMP>
        assert(contains(s,...
            "writetable(man_rows,manifest_tmp,'FileType','text')"),...
            'Gate 17 must force text output for the .tmp manifest');
        verifier=fileread(fullfile(patch_root,'+nrr_eval','verify_sha256_manifest.m'));
        assert(contains(verifier,...
            "readtable(manifest_path,'FileType','text','TextType','string')"),...
            'Manifest verifier must force text input for the .tmp manifest');
    end
    function test_manifest_mutation
        tmp=tempname(); repo=fullfile(tmp,'repo'); run_dir=fullfile(repo,'runs','r1');
        mkdir(fullfile(repo,'+nrr_eval')); mkdir(fullfile(run_dir,'08_freeze'));
        cleanup=onCleanup(@() cleanup_tmp(tmp));
        src=fullfile(repo,'dummy.m'); write_bytes(src,uint8('function dummy; end'));
        out=fullfile(run_dir,'result.txt'); write_bytes(out,uint8('stable'));
        manifest=fullfile(run_dir,'08_freeze','RUN_MANIFEST_SHA256.csv');
        T=nrr_eval.compute_sha256_manifest(run_dir,repo); writetable(T,manifest);
        r=nrr_eval.verify_sha256_manifest(manifest,run_dir,repo);
        assert(strcmp(r.status,'PASS'));
        write_bytes(out,uint8('mutated'));
        failed=false;
        try; nrr_eval.verify_sha256_manifest(manifest,run_dir,repo);
        catch ME; failed=contains(ME.message,'MISMATCH'); end
        assert(failed,'Post-manifest mutation was not detected');
        clear cleanup;
        cleanup_tmp(tmp);
    end
    function write_bytes(fp,bytes)
        fid=fopen(fp,'wb'); assert(fid>=0); c=onCleanup(@() close_if_valid(fid));
        fwrite(fid,bytes,'uint8'); fclose(fid); clear c;
    end
    function close_if_valid(fid)
        if any(openedFiles==fid); fclose(fid); end
    end
    function cleanup_tmp(tmp)
        if isfolder(tmp); rmdir(tmp,'s'); end
    end
end
