import React from 'react';

interface Props { userId: string; }

// ruleid: slopguard.react.href-js-scheme
// Unsafe: an arbitrary function call does not validate the URL scheme.
// getUserUrl() may return a javascript: or data: URL; only a recognised
// scheme-sanitizer (e.g. sanitizeUrl) is a safe inline call.
function UserProfile({ userId }: Props) {
  return (
    <div>
      <a href={getUserUrl(userId)}>Profile</a>
      <img src={getAvatarSrc(userId)} alt="avatar" />
    </div>
  );
}
