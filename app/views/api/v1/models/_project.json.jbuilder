json.id resource.id
json.account_id resource.account_id
json.name resource.name
json.description resource.description
json.status resource.status
json.color resource.color
json.start_date resource.start_date
json.end_date resource.end_date
json.created_by_id resource.created_by_id
json.progress resource.progress
json.tasks_count resource.tasks_count
json.completed_tasks_count resource.completed_tasks_count
json.member_ids resource.members.map(&:id)
json.members resource.members do |member|
  json.id member.id
  json.name member.name
  json.thumbnail member.avatar_url
end
json.created_at resource.created_at.to_i
json.updated_at resource.updated_at.to_i
