import React from 'react';
import { sanitizeUrl } from '@braintree/sanitize-url';

interface Props { url: string; imageSrc: string; }

// ok: slopguard.react.href-js-scheme — sanitizeUrl() validates the scheme and
// rejects javascript: and data: prefixes before the value reaches the attribute.
// NOTE: the rule fires on bare identifiers only; a variable *assigned* from a
// sanitizer on a prior line is a syntactic false-negative (dataflow needed for
// full coverage).  Inline call form is the reliably detectable safe pattern.
function SafeLink({ url, imageSrc }: Props) {
  return (
    <div>
      <a href={sanitizeUrl(url)}>Profile</a>
      <img src={sanitizeUrl(imageSrc)} alt="avatar" />
    </div>
  );
}

// ok: slopguard.react.href-js-scheme — sanitizeUrl() rejects unsafe schemes
function navigateSafe(userUrl: string) {
  window.location.href = sanitizeUrl(userUrl);
}

// ok: slopguard.react.href-js-scheme — arrow component using the real trusted
// import with no local shadow; Arm C2 must not fire here.
const ArrowSafeLink = ({ url, imageSrc }: Props) => {
  return (
    <div>
      <a href={sanitizeUrl(url)}>Profile</a>
      <img src={sanitizeUrl(imageSrc)} alt="avatar" />
    </div>
  );
};

// ok: slopguard.react.href-js-scheme — arrow utility with the real import
const arrowSafeNavigate = (userUrl: string) => {
  window.location.href = sanitizeUrl(userUrl);
};

export default SafeLink;
