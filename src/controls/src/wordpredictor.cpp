/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "wordpredictor.h"

#include <QCoreApplication>
#include <QFile>
#include <QHash>
#include <QLoggingCategory>
#include <QPointer>
#include <QThreadPool>

#include <algorithm>
#include <atomic>
#include <cstring>
#include <vector>

Q_LOGGING_CATEGORY(lcWords, "asteroid.keyboard.words", QtInfoMsg)

namespace {

struct Entry {
    quint32 key;      // offset of the lower-cased word in Words::keys
    quint32 word;     // offset of the word as listed in Words::words
    quint16 keyLen;
    quint16 wordLen;
    quint8 rank;      // SCOWL size: 10 the commonest .. 60
};

struct Words {
    QByteArray keys;
    QByteArray words;
    std::vector<Entry> entries;   // sorted by key

    QByteArray key(const Entry &e) const { return QByteArray::fromRawData(keys.constData() + e.key, e.keyLen); }
    QString word(const Entry &e) const { return QString::fromUtf8(words.constData() + e.word, e.wordLen); }
};

QString g_path = QStringLiteral("/usr/share/asteroid-keyboard/en_GB.words");
std::atomic<Words *> g_words { nullptr };
std::atomic<bool> g_started { false };
// the main thread's predictors waiting for the list, and what tells them
QList<QPointer<WordPredictor>> g_waiters;
QObject *g_notifier = nullptr;

/*
 * The words people write most, in order (messages on a watch first): they
 * come before every other word that completes what was typed. SCOWL ranks
 * words in steps of thousands; this orders the top of the list.
 */
const char *const COMMON[] = {
    "the", "I", "you", "to", "a", "and", "it", "is", "of", "in", "that", "for", "on", "be",
    "ok", "okay", "yes", "no", "thanks", "thank", "see", "soon", "have", "are", "was", "with",
    "my", "me", "this", "we", "at", "not", "do", "can", "will", "just", "so", "but", "what",
    "all", "get", "if", "about", "when", "your", "they", "there", "how", "good", "now",
    "going", "time", "today", "tomorrow", "tonight", "later", "love", "know", "like", "think",
    "here", "home", "out", "up", "there's", "I'm", "it's", "don't", "can't", "I'll", "let's",
    "that's", "you're", "we're", "didn't", "won't", "isn't", "haven't", "where", "why", "who",
    "which", "would", "could", "should", "been", "had", "has", "did", "does", "were", "am",
    "an", "or", "as", "by", "from", "one", "two", "three", "back", "come", "coming", "go",
    "got", "great", "sure", "sorry", "please", "hi", "hello", "hey", "yeah", "maybe", "minutes",
    "meet", "call", "later", "let", "really", "right", "still", "very", "much", "more", "need",
    "never", "next", "nice", "night", "morning", "done", "down", "feel", "fine", "find",
    "happy", "help", "hope", "keep", "last", "little", "long", "lot", "make", "made", "many",
    "miss", "off", "only", "over", "people", "put", "said", "say", "same", "send", "sent",
    "something", "sounds", "start", "stop", "take", "tell", "than", "then", "them", "these",
    "those", "thing", "things", "through", "too", "try", "until", "wait", "want", "way", "week",
    "well", "went", "while", "work", "working", "year", "yet", "again", "already", "always",
    "also", "any", "because", "before", "best", "better", "bring", "car", "check", "day",
    "dinner", "lunch", "breakfast", "else", "ever", "first", "free", "friend", "fun", "give",
    "glad", "guess", "hard", "heard", "house", "idea", "into", "just", "kind", "leave", "left",
    "life", "look", "looking", "most", "must", "new", "nothing", "other", "our", "own", "party",
    "phone", "place", "plan", "probably", "quite", "ready", "school", "show", "sleep", "some",
    "someone", "sometimes", "talk", "their", "thought", "told", "took", "us", "use", "watch",
    "water", "way", "where's", "whole", "with", "without", "wrong", "years", "after", "his",
    "her", "him", "she", "he", "its", "every", "even", "away", "around", "between", "under",
};

/* Written without the apostrophe (as on a phone keyboard): the contraction
 * comes first. Words that always take a capital ("I") get it. */
const char *const CONTRACTIONS[][2] = {
    { "im", "I'm" }, { "ive", "I've" }, { "id", "I'd" }, { "ill", "I'll" }, { "dont", "don't" },
    { "cant", "can't" }, { "wont", "won't" }, { "isnt", "isn't" }, { "didnt", "didn't" },
    { "doesnt", "doesn't" }, { "wasnt", "wasn't" }, { "werent", "weren't" }, { "arent", "aren't" },
    { "havent", "haven't" }, { "hasnt", "hasn't" }, { "couldnt", "couldn't" },
    { "wouldnt", "wouldn't" }, { "shouldnt", "shouldn't" }, { "thats", "that's" },
    { "whats", "what's" }, { "wheres", "where's" }, { "theres", "there's" }, { "youre", "you're" },
    { "theyre", "they're" }, { "were", "we're" }, { "lets", "let's" }, { "its", "it's" },
    { "youll", "you'll" }, { "well", "we'll" }, { "theyll", "they'll" }, { "youve", "you've" },
    { "weve", "we've" }, { "hes", "he's" }, { "shes", "she's" }, { "i", "I" },
};

QHash<QByteArray, QString> &contractions()
{
    static QHash<QByteArray, QString> map = [] {
        QHash<QByteArray, QString> h;
        for (const auto &c : CONTRACTIONS)
            h.insert(QByteArray(c[0]), QString::fromUtf8(c[1]));
        return h;
    }();
    return map;
}

QHash<QByteArray, int> &commonIndex()
{
    static QHash<QByteArray, int> index = [] {
        QHash<QByteArray, int> h;
        int i = 0;
        for (const char *w : COMMON) {
            const QByteArray k = QString::fromUtf8(w).toLower().toUtf8();
            if (!h.contains(k))
                h.insert(k, i++);
        }
        return h;
    }();
    return index;
}

Words *load(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        qCInfo(lcWords) << "no word list:" << path;
        return nullptr;
    }
    const QByteArray all = file.readAll();
    auto *w = new Words;
    w->entries.reserve(all.count('\n') + 1);
    w->words.reserve(all.size());
    w->keys.reserve(all.size());
    qsizetype pos = 0;
    while (pos < all.size()) {
        qsizetype end = all.indexOf('\n', pos);
        if (end < 0)
            end = all.size();
        const qsizetype tab = all.indexOf('\t', pos);
        if (tab > pos && tab < end) {
            const QByteArray word = all.mid(pos, tab - pos);
            const int rank = all.mid(tab + 1, end - tab - 1).toInt();
            const QByteArray key = QString::fromUtf8(word).toLower().toUtf8();
            if (!word.isEmpty() && word.size() < 0xffff && key.size() < 0xffff) {
                Entry e;
                e.key = quint32(w->keys.size());
                e.keyLen = quint16(key.size());
                e.word = quint32(w->words.size());
                e.wordLen = quint16(word.size());
                e.rank = quint8(qBound(1, rank, 255));
                w->keys.append(key);
                w->words.append(word);
                w->entries.push_back(e);
            }
        }
        pos = end + 1;
    }
    const Words *wp = w;
    std::sort(w->entries.begin(), w->entries.end(), [wp](const Entry &a, const Entry &b) {
        return wp->key(a) < wp->key(b);
    });
    qCInfo(lcWords) << w->entries.size() << "words from" << path;
    return w;
}

void startLoading()
{
    if (g_started.exchange(true))
        return;
    // made in the main thread: the worker's news is delivered there
    g_notifier = new QObject(QCoreApplication::instance());   // lives as long as the application
    QObject *notifier = g_notifier;
    // ASTEROID_KEYBOARD_WORDS: another list (tests)
    const QString path = qEnvironmentVariableIsSet("ASTEROID_KEYBOARD_WORDS")
            ? qEnvironmentVariable("ASTEROID_KEYBOARD_WORDS") : g_path;
    QThreadPool::globalInstance()->start([path, notifier] {
        Words *w = load(path);
        if (!w)
            return;
        g_words.store(w);
        QMetaObject::invokeMethod(notifier, [] {
            for (const QPointer<WordPredictor> &p : std::as_const(g_waiters)) {
                if (p)
                    emit p->availableChanged();
            }
            g_waiters.clear();
        }, Qt::QueuedConnection);
    });
}

// the range of entries whose key starts with prefix
std::pair<size_t, size_t> prefixRange(const Words *w, const QByteArray &prefix)
{
    auto lo = std::lower_bound(w->entries.begin(), w->entries.end(), prefix,
                               [w](const Entry &e, const QByteArray &p) { return w->key(e) < p; });
    auto hi = lo;
    while (hi != w->entries.end() && w->key(*hi).startsWith(prefix))
        ++hi;
    return { size_t(lo - w->entries.begin()), size_t(hi - w->entries.begin()) };
}

// Damerau-Levenshtein (adjacent transpositions), or max + 1 once over max
int distance(const QByteArray &a, const QByteArray &b, int max)
{
    const int n = a.size(), m = b.size();
    if (qAbs(n - m) > max || n > 62 || m > 62)
        return max + 1;
    int rows[3][64];
    int *prev2 = rows[0], *prev = rows[1], *cur = rows[2];
    for (int j = 0; j <= m; j++)
        prev[j] = j;
    for (int i = 1; i <= n; i++) {
        cur[0] = i;
        int rowMin = cur[0];
        const char ai = a.at(i - 1);
        for (int j = 1; j <= m; j++) {
            const int cost = ai == b.at(j - 1) ? 0 : 1;
            int v = std::min({ prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost });
            if (i > 1 && j > 1 && ai == b.at(j - 2) && a.at(i - 2) == b.at(j - 1))
                v = std::min(v, prev2[j - 2] + 1);
            cur[j] = v;
            rowMin = std::min(rowMin, v);
        }
        if (rowMin > max)
            return max + 1;
        int *t = prev2;
        prev2 = prev;
        prev = cur;
        cur = t;
    }
    return prev[m];
}

// the letters next to a key on QWERTY (the rows below sit half a key right)
QByteArray neighbours(char c)
{
    static const char *rows[] = { "qwertyuiop", "asdfghjkl", "zxcvbnm" };
    QByteArray n;
    if (!c)
        return n;
    for (int r = 0; r < 3; r++) {
        const char *p = strchr(rows[r], c);
        if (!p)
            continue;
        const int i = int(p - rows[r]);
        auto add = [&n](int rr, int ii) {
            if (rr < 0 || rr > 2 || ii < 0 || ii >= int(strlen(rows[rr])))
                return;
            n.append(rows[rr][ii]);
        };
        add(r, i - 1);
        add(r, i + 1);
        add(r - 1, i);
        add(r - 1, i + 1);
        add(r + 1, i - 1);
        add(r + 1, i);
    }
    return n;
}

QString inCase(const QString &typed, const QString &w)
{
    const bool listedCapital = w != w.toLower();
    const bool allUpper = typed.size() > 1 && typed == typed.toUpper() && typed != typed.toLower();
    if (allUpper)
        return w.toUpper();
    if (listedCapital)
        return w;
    if (!typed.isEmpty() && typed.at(0).isUpper()) {
        QString r = w;
        r[0] = r.at(0).toUpper();
        return r;
    }
    return w;
}

} // namespace

WordPredictor::WordPredictor(QObject *parent) : QObject(parent)
{
    if (!g_words.load())
        g_waiters.append(this);
    startLoading();
}

void WordPredictor::setWordsFile(const QString &path)
{
    g_path = path;
}

bool WordPredictor::available() const
{
    return g_words.load() != nullptr;
}

bool WordPredictor::isWord(const QString &word) const
{
    const Words *w = g_words.load();
    if (!w || word.isEmpty())
        return false;
    const QByteArray key = word.toLower().toUtf8();
    const auto r = prefixRange(w, key);
    for (size_t i = r.first; i < r.second; i++) {
        if (w->entries[i].keyLen == key.size())
            return true;
    }
    return false;
}

QStringList WordPredictor::suggest(const QString &typed, int count) const
{
    const Words *w = g_words.load();
    if (!w || typed.isEmpty() || count <= 0)
        return {};
    const QByteArray key = typed.toLower().toUtf8();
    const QHash<QByteArray, int> &common = commonIndex();
    auto isLower = [w](const Entry &e) {
        const char *p = w->words.constData() + e.word;
        for (int i = 0; i < e.wordLen; i++) {
            if (p[i] >= 'A' && p[i] <= 'Z')
                return false;
        }
        return true;
    };
    // the commonest words by their place in COMMON; the others by their
    // SCOWL size, names (listed with capitals, all from size 50 on) as if
    // they were commoner words of size 35
    auto scoreOf = [&common, w, &isLower](const Entry &e) {
        auto it = common.constFind(w->key(e));
        if (it != common.constEnd())
            return *it;
        const int rank = isLower(e) ? int(e.rank) : std::min(int(e.rank), 35);
        return 1000 + (rank - 10) * 60;
    };

    struct Candidate { int score; size_t entry; };
    std::vector<Candidate> out;
    QString exact;

    // the word itself, and the words it begins: one form a key (keys are
    // sorted, so the forms of a key are next to each other), the lower
    // case one when there is one
    const auto range = prefixRange(w, key);
    for (size_t i = range.first; i < range.second;) {
        size_t best = i, j = i + 1;
        while (j < range.second && w->entries[j].keyLen == w->entries[i].keyLen
               && w->key(w->entries[j]) == w->key(w->entries[i])) {
            if (isLower(w->entries[j]) && !isLower(w->entries[best]))
                best = j;
            j++;
        }
        const Entry &e = w->entries[best];
        if (e.keyLen == key.size()) {
            // a name keeps its capitals; a short and rare capitalised entry
            // ("Th", "Tu") is an abbreviation, not the word typed (even when
            // the keyboard capitalised it: "Th" at the start of a sentence)
            if (isLower(e))
                exact = typed;
            else if (e.keyLen >= 4 || e.rank <= 20 || common.contains(w->key(e)))
                exact = w->word(e);
        } else
            out.push_back({ scoreOf(e) + (int(e.keyLen) - int(key.size())), best });
        i = j;
    }

    // not a word: the words one letter off (two for longer words), the first
    // letter right or a neighbour of it on the keyboard; a common word one
    // letter off beats a rare completion ("teh": the, before Tehran)
    if (exact.isEmpty() && key.size() >= 2) {
        const int max = key.size() <= 4 ? 1 : 2;
        QByteArray firsts(1, key.at(0));
        firsts.append(neighbours(key.at(0)));
        for (char f : std::as_const(firsts)) {
            const auto r = prefixRange(w, QByteArray(1, f));
            for (size_t i = r.first; i < r.second; i++) {
                const Entry &e = w->entries[i];
                if (qAbs(int(e.keyLen) - int(key.size())) > max)
                    continue;
                const int d = distance(key, w->key(e), max);
                if (d > max || d == 0)
                    continue;
                // one form a key: not "Long" when there is "long"
                if (!isLower(e) && ((i > r.first && w->key(w->entries[i - 1]) == w->key(e) && isLower(w->entries[i - 1]))
                                    || (i + 1 < r.second && w->key(w->entries[i + 1]) == w->key(e) && isLower(w->entries[i + 1]))))
                    continue;
                // the longer the word typed, the likelier it is meant as it
                // begins ("lond": London before long)
                out.push_back({ d * 1000 + int(key.size()) * 400 + (f == key.at(0) ? 0 : 500) + scoreOf(e), i });
            }
        }
    }

    const size_t keep = std::min(out.size(), size_t(count) + 8);
    std::partial_sort(out.begin(), out.begin() + keep, out.end(), [](const Candidate &a, const Candidate &b) {
        return a.score != b.score ? a.score < b.score : a.entry < b.entry;
    });
    QStringList result;
    QList<QByteArray> seen { key };
    auto contraction = contractions().constFind(key);
    if (contraction != contractions().constEnd()) {
        result.append(inCase(typed, *contraction));
        seen.append(contraction->toLower().toUtf8());
    }
    if (!exact.isEmpty() && !(contraction != contractions().constEnd() && key == "i"))
        result.append(exact);
    for (size_t i = 0; i < keep && result.size() < count; i++) {
        const Entry &e = w->entries[out[i].entry];
        const QByteArray k = w->key(e);
        if (seen.contains(k))
            continue;
        seen.append(k);
        result.append(inCase(typed, w->word(e)));
    }
    return result;
}

QStringList WordPredictor::glideCandidates(const QString &firsts, const QString &lasts,
                                           int minLetters, int maxLetters, int limit) const
{
    const Words *w = g_words.load();
    if (!w || limit <= 0)
        return {};
    const QByteArray first = firsts.toLower().toLatin1();
    const QByteArray last = lasts.toLower().toLatin1();
    if (first.isEmpty() || last.isEmpty())
        return {};
    const QHash<QByteArray, int> &common = commonIndex();
    auto isLower = [w](const Entry &e) {
        const char *p = w->words.constData() + e.word;
        for (int i = 0; i < e.wordLen; i++) {
            if (p[i] >= 'A' && p[i] <= 'Z')
                return false;
        }
        return true;
    };
    // the same order as suggest(): the commonest words by their place in COMMON,
    // the others by SCOWL size (names as if of size 35)
    auto scoreOf = [&common, w, &isLower](const Entry &e) {
        auto it = common.constFind(w->key(e));
        if (it != common.constEnd())
            return *it;
        const int rank = isLower(e) ? int(e.rank) : std::min(int(e.rank), 35);
        return 1000 + (rank - 10) * 60;
    };
    struct Candidate { int score; size_t entry; };
    std::vector<Candidate> out;
    for (char f : first) {
        const auto r = prefixRange(w, QByteArray(1, f));
        for (size_t i = r.first; i < r.second; i++) {
            const Entry &e = w->entries[i];
            const QByteArray k = w->key(e);
            // only a-z and apostrophes; the glide has no key for anything else
            int letters = 0;
            bool ok = true;
            for (char ch : k) {
                if (ch >= 'a' && ch <= 'z')
                    letters++;
                else if (ch != '\'') {
                    ok = false;
                    break;
                }
            }
            if (!ok || letters < minLetters || letters > maxLetters)
                continue;
            char lastLetter = 0;
            for (int n = k.size() - 1; n >= 0; n--) {
                if (k.at(n) != '\'') {
                    lastLetter = k.at(n);
                    break;
                }
            }
            if (!last.contains(lastLetter))
                continue;
            // one form a key: the lower case one
            if (!isLower(e) && ((i > r.first && w->key(w->entries[i - 1]) == k && isLower(w->entries[i - 1]))
                                || (i + 1 < r.second && w->key(w->entries[i + 1]) == k && isLower(w->entries[i + 1]))))
                continue;
            out.push_back({ scoreOf(e), i });
        }
    }
    const size_t keep = std::min(out.size(), size_t(limit));
    std::partial_sort(out.begin(), out.begin() + keep, out.end(), [](const Candidate &a, const Candidate &b) {
        return a.score != b.score ? a.score < b.score : a.entry < b.entry;
    });
    QStringList result;
    result.reserve(int(keep));
    for (size_t i = 0; i < keep; i++)
        result.append(w->word(w->entries[out[i].entry]));
    return result;
}
