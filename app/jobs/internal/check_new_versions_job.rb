class Internal::CheckNewVersionsJob < ApplicationJob
  queue_as :scheduled_jobs

  # This fork ships its own versions, so fazer.ai's latest release is not an update for it and the
  # dashboard banner and the Super Admin dot must stay off. Deleting also drops a version stored
  # before this change, which never expires. The job stays scheduled for what Enterprise adds to it.
  def perform
    ::Redis::Alfred.delete(::Redis::Alfred::LATEST_CHATWOOT_VERSION)
  end
end

Internal::CheckNewVersionsJob.prepend_mod_with('Internal::CheckNewVersionsJob')
