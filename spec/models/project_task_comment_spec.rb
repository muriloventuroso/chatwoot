require 'rails_helper'

RSpec.describe ProjectTaskComment do
  it 'validates presence of content' do
    comment = build(:project_task_comment, content: nil)
    expect(comment).not_to be_valid
  end
end
