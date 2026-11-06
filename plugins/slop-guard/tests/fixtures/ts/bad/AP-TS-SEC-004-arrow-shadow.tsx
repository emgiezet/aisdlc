import React from 'react';
import { sanitizeUrl } from '@braintree/sanitize-url';

// Adversarial: the trusted named import IS present at the module level, but
// each arrow function/component declares a local `const sanitizeUrl = ...` that
// shadows the imported binding within that arrow body.  The local is a
// pure pass-through that applies no scheme validation.
// Arm C only matches `function F(...)` bodies; Arm C2 extends coverage to
// `const F = (...) => { ... }` bodies.

interface Props { url: string; imageSrc: string; }

// ruleid: slopguard.react.href-js-scheme
const ArrowShadowLink = ({ url, imageSrc }: Props) => {
  // Shadows the imported sanitizeUrl — no sanitization happens.
  const sanitizeUrl = (u: string): string => u;
  return (
    <div>
      <a href={sanitizeUrl(url)}>Profile</a>
      <img src={sanitizeUrl(imageSrc)} alt="avatar" />
    </div>
  );
};

// ruleid: slopguard.react.href-js-scheme
const arrowShadowNavigate = (userUrl: string) => {
  // Arrow utility — local shadow bypasses the real sanitizer.
  const sanitizeUrl = (u: string): string => u;
  window.location.href = sanitizeUrl(userUrl);
};

export default ArrowShadowLink;
