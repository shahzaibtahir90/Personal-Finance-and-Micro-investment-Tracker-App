-- SQL for consultant invitation approval and linking
-- This trigger moves a consultant from pending to active for a user upon approval

CREATE OR REPLACE FUNCTION approve_consultant_invitation(invitation_id uuid, consultant_id uuid) RETURNS void AS $$
BEGIN
  -- Mark invitation as approved
  UPDATE consultant_invitations
    SET status = 'approved'
    WHERE id = invitation_id;

  -- Link consultant to user (inviter)
  INSERT INTO user_consultants (user_id, consultant_id)
    SELECT inviter_id, consultant_id
    FROM consultant_invitations
    WHERE id = invitation_id
    ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql;

-- Usage example (call from backend or edge function after consultant registers):
-- SELECT approve_consultant_invitation('<invitation_id>', '<consultant_id>');
