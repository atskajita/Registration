% INPUTS:
% run_num_list is the index list of the experiment for the specified sample
function calculateDescriptorsInParallel(run_num_list)

    loadExperimentParams;

    run_num_list_size = length(run_num_list);
    desc_size = params.ROWS_DESC * params.COLS_DESC;
    run_size  = run_num_list_size * desc_size;

    disp('set up cluster')
    tic;
    cluster = parcluster('local_96workers');
    toc;

    tic;
    disp('create batch jobs')

    max_running_jobs = 18;
    waiting_sec = 10;

    jobs = cell(1, run_size);
    running_jobs = zeros(1,run_size);
    job_count = 1;

    while job_count <= run_size || sum(running_jobs) > 0
        if (job_count <= run_size) && (sum(running_jobs) < max_running_jobs)
            running_jobs(job_count) = 1;

            run_num    = run_num_list(ceil(job_count / desc_size));
            target_idx = mod(job_count, desc_size);
            if target_idx == 0
                target_idx = desc_size;
            end

            disp(['create batch (',num2str(job_count),') run_num=',num2str(run_num),', target_idx=',num2str(target_idx)])
            jobs{job_count} = batch(cluster,@calculateDescriptors,0,{run_num,target_idx,target_idx},'Pool',2,'CaptureDiary',true);
            job_count = job_count+1;
        else
            for job_id = find(running_jobs==1)
                job = jobs{job_id};
                is_finished = 0;
                if strcmp(job.State,'finished') || strcmp(job.State,'failed')
                    disp(['batch (',num2str(job_id),') has ',job.State,'.'])
                    running_jobs(job_id) = 0;
                    run_num    = run_num_list(ceil(job_id / desc_size));
                    target_idx = mod(job_id, desc_size);
                    if target_idx == 0
                        target_idx = desc_size;
                    end
                    diary(jobs{job_id},['./matlab-calcDesc-',num2str(run_num),'-',num2str(target_idx),'.log']);
                    delete(job)
                    is_finished = 1;
                end
            end
            if is_finished == 0
              disp(['waiting (',num2str(waiting_sec),' sec)... ',num2str(find(running_jobs==1))])
              pause(waiting_sec);

            end

        end
    end

    disp('all batch jobs finished')
    toc;

end
