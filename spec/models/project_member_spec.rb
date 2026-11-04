require 'rails_helper'

RSpec.describe ProjectMember do
  let(:project) { create(:project) }

  it 'is valid for a user of the project account' do
    member = build(:project_member, project: project)
    expect(member).to be_valid
  end

  it 'does not allow the same user twice on a project' do
    existing = create(:project_member, project: project)
    duplicate = build(:project_member, project: project, user: existing.user)
    expect(duplicate).not_to be_valid
  end

  it 'does not allow a user from another account' do
    member = build(:project_member, project: project, user: create(:user))
    expect(member).not_to be_valid
    expect(member.errors[:user]).to be_present
  end
end
