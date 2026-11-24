import React from 'react';
import { sanitizeUrl } from '@braintree/sanitize-url';

// Adversarial: the trusted named import IS present at the module level, but
// each function declares a local `const sanitizeUrl = ...` that shadows the
// import within that function's scope.  The local binding is a pure pass-through
// and provides no scheme sanitization.  TypeScript allows a function-scoped
// const to shadow a module-level import without a compile error; the rule must
// detect the function-local shadow even when the top-level import exists.

interface Props { url: string; imageSrc: string; }

// ruleid: slopguard.react.href-js-scheme
function ImportShadowLink({ url, imageSrc }: Props) {
  // Shadows the imported sanitizeUrl within this function — pure pass-through.
  const sanitizeUrl = (u: string): string => u;
  return (
    <div>
      <a href={sanitizeUrl(url)}>Profile</a>
      <img src={sanitizeUrl(imageSrc)} alt="avatar" />
    </div>
  );
}

// ruleid: slopguard.react.href-js-scheme
function importShadowNavigate(userUrl: string) {
  // Local shadow — not the imported sanitizeUrl.
  const sanitizeUrl = (u: string): string => u;
  window.location.href = sanitizeUrl(userUrl);
}

export default ImportShadowLink;
