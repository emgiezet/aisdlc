import React from 'react';

// Adversarial: a locally-defined function named sanitizeUrl that is actually a
// pass-through — identical in name to @braintree/sanitize-url but provides no
// scheme validation.  A purely name-based exclusion (without import check) would
// silently pass this, making the rule trivially bypassable.
const sanitizeUrl = (url: string): string => url;

interface Props { url: string; imageSrc: string; }

// ruleid: slopguard.react.href-js-scheme
function ShadowLink({ url, imageSrc }: Props) {
  return (
    <div>
      {/* href with locally-shadowed sanitizeUrl — no @braintree import present */}
      <a href={sanitizeUrl(url)}>Profile</a>
      {/* src with locally-shadowed sanitizeUrl */}
      <img src={sanitizeUrl(imageSrc)} alt="avatar" />
    </div>
  );
}

// ruleid: slopguard.react.href-js-scheme
function shadowNavigate(userUrl: string) {
  // window.location.href with locally-shadowed sanitizeUrl
  window.location.href = sanitizeUrl(userUrl);
}

export default ShadowLink;
