rollout_log_probs = batch.batch["rollout_log_probs"] # pi_vllm
actor_old_log_probs = batch.batch["old_log_probs"] # pi_fsdp
response_mask = batch.batch["response_mask"]
log_ratio = actor_old_log_probs - rollout_log_probs 
vllm_k3_kl_matrix = torch.exp(log_ratio) - log_ratio - 1
vllm_k3_kl = masked_mean(vllm_k3_kl_matrix,response_mask)
